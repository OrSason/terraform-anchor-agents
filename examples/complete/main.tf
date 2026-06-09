# Turnkey root: configures every provider the module needs (including the Anchor
# login → restapi bearer dance), then calls the module. Copy this pattern into
# your infra repo and point `source` at the published module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.14" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    restapi    = { source = "Mastercard/restapi", version = "~> 2.0" }
    http       = { source = "hashicorp/http", version = "~> 3.4" }
  }
}

# ---- Obtain a super-admin JWT (skipped if anchor_admin_token is supplied) ----
locals {
  do_login     = var.register_agents_in_anchor && var.anchor_admin_token == ""
  anchor_token = var.anchor_admin_token != "" ? var.anchor_admin_token : (local.do_login ? try(jsondecode(data.http.anchor_login[0].response_body).data.accessToken, "") : "")
}

data "http" "anchor_login" {
  count  = local.do_login ? 1 : 0
  url    = "${trimsuffix(var.anchor_url, "/")}/api/v1/auth/login"
  method = "POST"

  request_headers = { Content-Type = "application/json" }
  request_body    = jsonencode({ email = var.anchor_admin_email, password = var.anchor_admin_password })

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Anchor login failed (HTTP ${self.status_code}). Check credentials or supply anchor_admin_token."
    }
  }
}

# ---- Providers ----
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "kubectl" {
  config_path       = var.kubeconfig_path
  config_context    = var.kube_context != "" ? var.kube_context : null
  load_config_file  = true
  apply_retry_count = 3
}

provider "aws" {
  region = var.aws_region
}

provider "restapi" {
  uri                  = var.anchor_url
  write_returns_object = true

  headers = {
    Authorization = "Bearer ${local.anchor_token}"
    Content-Type  = "application/json"
  }

  create_method  = "POST"
  update_method  = "PATCH"
  destroy_method = "DELETE"
}

# ---- The module ----
module "anchor_agents" {
  source = "../../"

  environment = var.environment
  anchor_url  = var.anchor_url

  register_agents_in_anchor = var.register_agents_in_anchor

  external_secrets = var.external_secrets
  agents           = var.agents
}

output "agent_ids" {
  value = module.anchor_agents.agent_ids
}

output "agent_secret_arns" {
  value = module.anchor_agents.agent_secret_arns
}
