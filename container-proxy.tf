data "aws_iam_policy_document" "egress_proxy_read_config_files" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      var.config_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${var.config_bucket.arn}/${var.squid_config_s3_main_prefix}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      var.kms_key,
    ]
  }
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    sid     = "EcsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "egress_proxy" {
  name               = "${var.service}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_policy" "egress_proxy_read_config_files" {
  name        = "${var.service}-${var.env}-s3-access-to-config-files"
  description = "Grants the Egress Proxy access to config files stored in S3"
  policy      = data.aws_iam_policy_document.egress_proxy_read_config_files.json
}

resource "aws_iam_role_policy_attachment" "egress_proxy_read_config_files" {
  policy_arn = aws_iam_policy.egress_proxy_read_config_files.arn
  role       = aws_iam_role.egress_proxy.name
}

resource "aws_cloudwatch_log_group" "egress_proxy" {
  name              = "/aws/ecs/main/${var.env}-internet-proxy"
  retention_in_days = 30
}

resource "aws_iam_role" "ecs_task_execution_role" {
  count              = var.ecs_task_execution_role == null ? 1 : 0
  name               = "${var.service}-${var.env}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  tags = {
    Name = "proxy-ecs-task-execution"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  count      = var.ecs_task_execution_role == null ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "egress_proxy" {
  family                   = "squid-s3"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.egress_proxy.arn
  execution_role_arn       = var.ecs_task_execution_role != null ? data.aws_iam_role.ecs_task_execution_role[0].arn : aws_iam_role.ecs_task_execution_role[0].arn

  container_definitions = <<DEFINITION
[
  {
    "image": "${var.image}",
    "name": "squid-s3",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.proxy_port}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.egress_proxy.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "container-internet-proxy"
      }
    },
    "placementStrategy": [
      {
        "field": "attribute:ecs.availability-zone",
        "type": "spread"
      }
    ],
    "environment": [
      {
        "name": "SQUID_CONFIG_S3_BUCKET",
        "value": "${var.config_bucket.id}"
      },
      {
        "name": "SQUID_CONFIG_S3_PREFIX",
        "value": "${var.squid_config_s3_main_prefix}"
      },
      {
        "name": "PROXY_CFG_CHANGE_DEPENDENCY",
        "value": "${md5(file("${path.module}/config/ecs_squid_conf.tpl"))}"
      },
      {
        "name": "PROXY_ALLOWLIST_CHANGE_DEPENDENCY",
        "value": "${md5(jsonencode(var.acl))}"
      }
    ]
  }
]
DEFINITION

}


resource "aws_ecs_service" "egress_proxy" {
  name                   = "${var.service}-${var.env}"
  cluster                = var.ecs_cluster
  task_definition        = aws_ecs_task_definition.egress_proxy.arn
  desired_count          = var.size != null ? var.size : length(data.aws_availability_zones.available.names)
  launch_type            = var.ecs_launch_type
  enable_execute_command = var.enable_execute_command

  network_configuration {
    security_groups = [aws_security_group.egress_proxy.id]
    subnets         = data.aws_subnet.subnets.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.egress_proxy.arn
    container_name   = "squid-s3"
    container_port   = var.proxy_port
  }
}

resource "aws_acm_certificate" "egress_proxy" {
  domain_name       = "${var.subdomain}.${var.parent_domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.egress_proxy.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.id
}

resource "aws_acm_certificate_validation" "internet_proxy" {
  certificate_arn         = aws_acm_certificate.egress_proxy.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_lb" "egress_proxy" {
  name               = "${var.service}-${var.env}"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.aws_subnet.subnets.*.id

  dynamic "access_logs" {
    for_each = var.load_balancer_access_log_bucket_id != null ? [var.load_balancer_access_log_bucket_id] : []
    content {
      bucket  = access_logs.value
      prefix  = "ELBLogs/${var.service}-${var.env}"
      enabled = true
    }
  }
}

resource "aws_lb_target_group" "egress_proxy" {
  name              = "${var.service}-${var.env}"
  port              = var.proxy_port
  protocol          = "TCP"
  target_type       = "ip"
  vpc_id            = data.aws_vpc.vpc.id
  proxy_protocol_v2 = true

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.service}-${var.env}"
  }
}

resource "aws_lb_listener" "egress_proxy" {
  load_balancer_arn = aws_lb.egress_proxy.arn
  port              = var.proxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.egress_proxy.arn
  }
}

resource "aws_lb_listener" "egress_proxy_tls" {
  load_balancer_arn = aws_lb.egress_proxy.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = aws_acm_certificate.egress_proxy.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.egress_proxy.arn
  }

  depends_on = [aws_acm_certificate_validation.internet_proxy]
}

resource "aws_security_group" "egress_proxy" {
  name   = "${var.env}-internet-proxy"
  vpc_id = data.aws_vpc.vpc.id
}

resource "aws_security_group_rule" "egress_proxy_ingress" {
  description       = "Egress proxy users"
  type              = "ingress"
  cidr_blocks       = var.ingress_network_access
  protocol          = "tcp"
  from_port         = var.proxy_port
  to_port           = var.proxy_port
  security_group_id = aws_security_group.egress_proxy.id
}

resource "aws_security_group_rule" "ecs_to_s3" {
  count             = var.use_s3_vpc_endpoint ? 1 : 0
  description       = "Allow ECS to reach S3 (for Docker pull from ECR)"
  type              = "egress"
  prefix_list_ids   = [data.aws_vpc_endpoint.s3[0].prefix_list_id]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.egress_proxy.id
}

resource "aws_security_group_rule" "egress_proxy_egress" {
  for_each = { for v in var.egress_network_ports : v => v }

  description       = "Allow Egress Proxy out to port ${each.key}"
  type              = "egress"
  cidr_blocks       = var.egress_network_access
  protocol          = "tcp"
  from_port         = each.value
  to_port           = each.value
  security_group_id = aws_security_group.egress_proxy.id
}

resource "aws_s3_bucket_object" "ecs_squid_conf" {
  bucket     = var.config_bucket.id
  key        = "${var.squid_config_s3_main_prefix}/squid.conf"
  kms_key_id = var.kms_key
  content = templatefile("${path.module}/config/ecs_squid_conf.tpl", {
    acl = {
      sources      = var.acl.sources
      destinations = var.acl.destinations
      rules        = var.acl.rules
    }
  })
}

resource "aws_s3_bucket_object" "ecs_allowlists" {
  for_each   = var.acl.destinations
  bucket     = var.config_bucket.id
  key        = "${var.squid_config_s3_main_prefix}/conf.d/allowlist_${each.key}"
  content    = each.value
  kms_key_id = var.kms_key
}

resource "aws_route53_record" "egress_proxy" {
  zone_id = data.aws_route53_zone.private.id
  name    = "${var.subdomain}.${var.parent_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.egress_proxy.dns_name
    zone_id                = aws_lb.egress_proxy.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "egress_proxy_public" {
  zone_id = data.aws_route53_zone.public.id
  name    = "${var.subdomain}.${var.parent_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.egress_proxy.dns_name
    zone_id                = aws_lb.egress_proxy.zone_id
    evaluate_target_health = true
  }
}

## ECS Exec Policy

resource "aws_iam_policy" "ecs_ssm_policy" {
  count = var.enable_execute_command ? 1 : 0

  name        = "${var.service}-${var.env}-ecs-task-role-ssm-policy"
  description = "Policy allowing ECS execute command on egress proxy container."
  policy      = data.aws_iam_policy_document.ecs_ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  count = var.enable_execute_command ? 1 : 0

  role       = aws_iam_role.egress_proxy.name
  policy_arn = aws_iam_policy.ecs_ssm_policy[0].arn
}

data "aws_iam_policy_document" "ecs_ssm_policy" {
  statement {
    sid    = "ECSExec"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}
