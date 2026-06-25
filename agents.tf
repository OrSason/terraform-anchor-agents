# ---------------------------------------------------------------------------
# 1) Register each agent in Anchor's control plane and capture its one-time key.
#    The plaintext key is only returned on create; we read it from create_response.
# ---------------------------------------------------------------------------
resource "restapi_object" "agent" {
  for_each = var.register_agents_in_anchor ? var.agents : {}

  path         = "/api/v1/service-agents"
  id_attribute = "data/id"

  data = jsonencode({
    name                 = each.key
    description          = each.value.description
    allowedResourceTypes = each.value.allowed_resource_types
    allowSecretValues    = each.value.allow_secret_values
    labels               = each.value.labels
    expiresInDays        = each.value.expires_in_days
    scopes = [
      for s in each.value.scopes : {
        projectId     = s.project_id
        environmentId = s.environment_id
      }
    ]
  })

  lifecycle {
    # Anchor never returns the api_key on read, and scope/field edits are best
    # made via the Anchor UI/API; avoid perpetual diffs on the create body.
    ignore_changes = [data]
  }
}

# ---------------------------------------------------------------------------
# 2) Store each agent's API key in AWS Secrets Manager as { "apiKey": "<key>" }.
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "agent" {
  for_each = var.create_secrets ? var.agents : {}

  name        = local.agent_aws_keys[each.key]
  description = "Anchor service-agent API key for '${each.key}' (${var.environment})."

  tags = {
    "managed-by"      = "terraform"
    "anchor.io/agent" = each.key
    "anchor.io/env"   = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "agent" {
  for_each = var.create_secrets ? var.agents : {}

  secret_id     = aws_secretsmanager_secret.agent[each.key].id
  secret_string = jsonencode({ apiKey = local.agent_keys[each.key] })
}

# ---------------------------------------------------------------------------
# 3) ExternalSecret: sync the AWS secret into a k8s Secret <name>-credential.
# ---------------------------------------------------------------------------
resource "kubectl_manifest" "agent_external_secret" {
  for_each = var.agents

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "${each.key}-credential"
      namespace = var.agents_namespace
      labels    = merge(local.common_labels, { "anchor.io/agent" = each.key })
    }
    spec = {
      refreshInterval = var.external_secrets.refresh_interval
      secretStoreRef = {
        name = var.external_secrets.secret_store_name
        kind = var.external_secrets.secret_store_kind
      }
      target = {
        name           = "${each.key}-credential"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "apiKey"
          remoteRef = {
            key      = local.agent_aws_keys[each.key]
            property = "apiKey"
          }
        }
      ]
    }
  })

  server_side_apply = true

  depends_on = [
    kubernetes_namespace.agents,
    aws_secretsmanager_secret_version.agent,
  ]
}

# ---------------------------------------------------------------------------
# 4) AnchorAgent CR — the operator reconciles this into the gateway
#    Deployment/Service/ConfigMap, using the synced credential Secret.
# ---------------------------------------------------------------------------
resource "kubectl_manifest" "agent" {
  for_each = var.agents

  yaml_body = yamlencode({
    apiVersion = "anchor.io/v1alpha1"
    kind       = "AnchorAgent"
    metadata = {
      name      = each.key
      namespace = var.agents_namespace
      labels    = merge(local.common_labels, { "anchor.io/agent" = each.key })
    }
    spec = {
      agentName     = each.key
      anchorBaseUrl = local.anchor_api_base_url
      image         = local.agent_images[each.key]
      replicas      = each.value.replicas
      agentVersion  = each.value.agent_version
      credentialSecretRef = {
        name = "${each.key}-credential"
        key  = "apiKey"
      }
      cacheTtlMs            = each.value.cache_ttl_ms
      heartbeatIntervalMs   = each.value.heartbeat_interval_ms
      logLevel              = each.value.log_level
      mcpEnabled            = each.value.mcp_enabled
      allowedProjectIds     = local.agent_allowed_project_ids[each.key]
      allowedEnvironmentIds = local.agent_allowed_environment_ids[each.key]
    }
  })

  server_side_apply = true
  wait              = true

  depends_on = [
    kubectl_manifest.operator,              # CRD must exist first
    kubectl_manifest.agent_external_secret, # credential Secret must exist first
  ]
}
