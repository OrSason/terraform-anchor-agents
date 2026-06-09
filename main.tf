locals {
  # Gateway upstream endpoint.
  anchor_api_base_url = "${trimsuffix(var.anchor_url, "/")}/api/v1"

  # AWS Secrets Manager path prefix for agent keys.
  secret_prefix = var.aws_secret_name_prefix != "" ? var.aws_secret_name_prefix : "anchor/${var.environment}/agents"

  # Where the operator manifests live (bundled with the module by default).
  operator_manifest_dir = var.operator_manifest_dir != "" ? var.operator_manifest_dir : "${path.module}/manifests"

  # Common labels stamped on everything this module manages.
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "anchor-agents"
    "anchor.io/environment"        = var.environment
  }

  # Per-agent derived values.
  agent_images = {
    for name, a in var.agents : name => coalesce(a.image, var.gateway_image)
  }

  agent_aws_keys = {
    for name, a in var.agents : name => coalesce(a.aws_remote_key, "${local.secret_prefix}/${name}")
  }

  # Defense-in-depth allow-lists for the gateway, derived from each agent's scopes.
  agent_allowed_project_ids = {
    for name, a in var.agents : name => distinct([for s in a.scopes : s.project_id])
  }

  agent_allowed_environment_ids = {
    for name, a in var.agents : name => distinct([
      for s in a.scopes : s.environment_id if s.environment_id != null
    ])
  }

  # The API key per agent: captured from registration, or supplied directly.
  agent_keys = {
    for name, a in var.agents : name => (
      var.register_agents_in_anchor
      ? try(jsondecode(restapi_object.agent[name].create_response).data.apiKey, "")
      : coalesce(a.api_key, "")
    )
  }
}
