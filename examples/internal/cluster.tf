resource "aws_ecs_cluster" "example" {
  name = "${var.service}-${var.env}"

  tags = {
    Name = "${var.service}-${var.env}"
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  lifecycle {
    ignore_changes = [
      setting,
    ]
  }
}
