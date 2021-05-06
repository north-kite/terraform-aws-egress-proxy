data "aws_secretsmanager_secret_version" "internet_egress" {
  secret_id = "/internet-egress"
}

locals {
  account = {
    management-dev = ""
    management     = ""
    development    = ""
    qa             = ""
    integration    = ""
    preprod        = ""
    production     = ""
  }

  mgmt_account_mapping = {
    management-dev = ["development", "qa", "integration"]
    management     = ["preprod", "production"]
  }

  common_tags = {
    Environment = local.environment
    Application = "aws-internet-egress"
    CreatedBy   = "terraform"
    Owner       = "platform"
  }

  environment = terraform.workspace == "default" ? "management-dev" : terraform.workspace

  cidr_block = {
    management-dev = "x.x.x.x/24"
    management     = "x.x.x.x/24"
  }

  squid_config_s3_main_prefix = "internet-proxy"

  ecs_squid_config_s3_main_prefix = "container-internet-proxy"

  squid_conf_filename = "squid.conf"

  cw_agent_namespace                                    = "/app/internet_proxy"
  cw_agent_log_group_name                               = "/app/internet_proxy"
  cw_agent_metrics_collection_interval                  = 60
  cw_agent_cpu_metrics_collection_interval              = 60
  cw_agent_disk_measurement_metrics_collection_interval = 60
  cw_agent_disk_io_metrics_collection_interval          = 60
  cw_agent_mem_metrics_collection_interval              = 60
  cw_agent_netstat_metrics_collection_interval          = 60

  asg_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  env_prefix = {
    development    = "dev."
    qa             = "qa."
    stage          = "stg."
    integration    = "int."
    preprod        = "pre."
    production     = ""
    management-dev = "mgt-dev."
    management     = "mgt."
  }

  dw_domain = "${local.env_prefix[local.environment]}${local.parent_domain}"

  host_ranges = jsondecode(data.aws_secretsmanager_secret_version.internet_egress.secret_binary)["host_ranges"]

  whitelist_names = {
    ci_cd        = "whitelist_ci_cd"
    packer       = "whitelist_packer"
    aws_services = "whitelist_aws_services"
  }

  whitelists = [
    "ci_cd",
    "packer",
    "aws_services",
  ]

  deploy_ithc_infra = {
    management-dev = false
    management     = false
  }

}
