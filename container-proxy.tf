data "aws_iam_policy_document" "container_internet_proxy_read_config" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.management.outputs.config_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${data.terraform_remote_state.management.outputs.config_bucket.arn}/${local.ecs_squid_config_s3_main_prefix}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      data.terraform_remote_state.management.outputs.config_bucket.cmk_arn,
    ]
  }
}

resource "aws_iam_role" "container_internet_proxy" {
  name               = "InternetProxy"
  assume_role_policy = data.terraform_remote_state.management.outputs.ecs_assume_role_policy_json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "container_internet_proxy" {
  policy = data.aws_iam_policy_document.container_internet_proxy_read_config.json
  role   = aws_iam_role.container_internet_proxy.id
}

resource "aws_cloudwatch_log_group" "internet_proxy_ecs" {
  name              = "/aws/ecs/main/internet-proxy"
  retention_in_days = 30
  tags              = local.common_tags
}

# Note that the CONTAINER_VERSION environment variable below is just a dummy
# variable. If you need the ECS service to deploy an updated container version,
# just change that number (to anything). Future work will put proper version
# tags on the container image itself, at which point that psuedo-version
# environment variable can be removed again
resource "aws_ecs_task_definition" "container_internet_proxy" {
  family                   = "squid-s3"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.container_internet_proxy.arn
  execution_role_arn       = data.terraform_remote_state.management.outputs.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
[
  {
    "image": "${local.account[local.environment]}.${module.vpc.ecr_dkr_domain_name}/squid-s3:latest",
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
        "awslogs-group": "${aws_cloudwatch_log_group.internet_proxy_ecs.name}",
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
        "value": "${data.terraform_remote_state.management.outputs.config_bucket.id}"
      },
      {
        "name": "SQUID_CONFIG_S3_PREFIX",
        "value": "${local.ecs_squid_config_s3_main_prefix}"
      },
      {
        "name": "CONTAINER_VERSION",
        "value": "0.0.1"
      },
      {
        "name": "PROXY_CFG_CHANGE_DEPENDENCY",
        "value": "${md5(data.template_file.ecs_squid_conf.rendered)}"
      },
      {
        "name": "PROXY_WHITELIST_CHANGE_DEPENDENCY",
        "value": "${md5(join(",", formatlist("%s", data.template_file.ecs_whitelists[*].rendered)))}"
      }
    ]
  }
]
DEFINITION

}

resource "aws_ecs_service" "container_internet_proxy" {
  name            = "container-internet-proxy"
  cluster         = data.terraform_remote_state.management.outputs.ecs_cluster_main.id
  task_definition = aws_ecs_task_definition.container_internet_proxy.arn
  desired_count   = length(data.aws_availability_zones.available.names)
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.internet_proxy.id]
    subnets         = aws_subnet.proxy.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.container_internet_proxy.arn
    container_name   = "squid-s3"
    container_port   = var.proxy_port
  }
}

resource "aws_acm_certificate" "internet_proxy" {
  domain_name       = "proxy.${local.dw_domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name     = aws_acm_certificate.internet_proxy.domain_validation_options[0].resource_record_name
  type     = aws_acm_certificate.internet_proxy.domain_validation_options[0].resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.internet_proxy.domain_validation_options[0].resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_acm_certificate_validation" "internet_proxy" {
  certificate_arn         = aws_acm_certificate.internet_proxy.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

resource "aws_lb" "container_internet_proxy" {
  name               = "container-internet-proxy"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.proxy.*.id
  tags               = local.common_tags

  access_logs {
    bucket  = data.terraform_remote_state.security_tools.outputs.logstore_bucket.id
    prefix  = "ELBLogs/container-internet-proxy"
    enabled = true
  }
}

resource "aws_lb_target_group" "container_internet_proxy" {
  name              = "container-internet-proxy"
  port              = var.proxy_port
  protocol          = "TCP"
  target_type       = "ip"
  vpc_id            = module.vpc.vpc.id
  proxy_protocol_v2 = true

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    { Name = "container-internet-proxy" },
  )
}

resource "aws_lb_listener" "container_internet_proxy" {
  load_balancer_arn = aws_lb.container_internet_proxy.arn
  port              = var.proxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.container_internet_proxy.arn
  }
}

resource "aws_lb_listener" "container_internet_proxy_tls" {
  load_balancer_arn = aws_lb.container_internet_proxy.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = aws_acm_certificate.internet_proxy.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.container_internet_proxy.arn
  }

  depends_on = [aws_acm_certificate_validation.internet_proxy]
}

resource "aws_security_group" "internet_proxy" {
  name   = "internet-proxy"
  vpc_id = module.vpc.vpc.id
}

resource "aws_security_group_rule" "internet_proxy" {
  description       = "Internet proxy users"
  type              = "ingress"
  cidr_blocks       = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  protocol          = "tcp"
  from_port         = var.proxy_port
  to_port           = var.proxy_port
  security_group_id = aws_security_group.internet_proxy.id
}

resource "aws_security_group_rule" "ecs_to_s3" {
  description       = "Allow ECS to reach S3 (for Docker pull from ECR)"
  type              = "egress"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.internet_proxy.id
}

resource "aws_security_group_rule" "internet_proxy_to_internet_https" {
  description       = "Allow Internet Proxy to reach all Internet hosts (HTTPS)"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.internet_proxy.id
}

resource "aws_security_group_rule" "internet_proxy_to_internet_http" {
  description       = "Allow Internet Proxy to reach all Internet hosts (HTTP)"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.internet_proxy.id
}

data "template_file" "ecs_squid_conf" {
  template = file("config/ecs_squid_conf.tpl")

  vars = {
    environment = local.environment

    cidr_block_packer_mgmtdev          = local.host_ranges.management-dev.packer-vpc
    cidr_block_ci_cd_mgmtdev           = local.host_ranges.management-dev.ci-cd-vpc
    cidr_block_internet_egress_mgmtdev = local.cidr_block.management-dev

    cidr_block_packer_mgmt          = local.host_ranges.management.packer-vpc
    cidr_block_ci_cd_mgmt           = local.host_ranges.management.ci-cd-vpc
    cidr_block_internet_egress_mgmt = local.cidr_block.management

    whitelist_ci_cd_name        = local.whitelist_names.ci_cd
    whitelist_packer_name       = local.whitelist_names.packer
    whitelist_aws_services_name = local.whitelist_names.aws_services
  }
}

resource "aws_s3_bucket_object" "ecs_squid_conf" {
  bucket     = data.terraform_remote_state.management.outputs.config_bucket.id
  key        = "${local.ecs_squid_config_s3_main_prefix}/${local.squid_conf_filename}"
  content    = data.template_file.ecs_squid_conf.rendered
  kms_key_id = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn
}


data template_file "ecs_whitelists" {
  count    = length(local.whitelists)
  template = file("config/whitelist_${local.whitelists[count.index]}.tpl")

  vars = {
    environment = local.environment
  }
}

resource "aws_s3_bucket_object" "ecs_whitelists" {
  count      = length(local.whitelists)
  bucket     = data.terraform_remote_state.management.outputs.config_bucket.id
  key        = "${local.ecs_squid_config_s3_main_prefix}/conf.d/whitelist_${local.whitelists[count.index]}"
  content    = data.template_file.ecs_whitelists[count.index].rendered
  kms_key_id = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn
}
