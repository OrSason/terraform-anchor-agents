output "agent_ids" {
  description = "Anchor service-agent UUIDs, keyed by agent name (only when registered by this module)."
  value       = { for name, r in restapi_object.agent : name => r.id }
}

output "agent_secret_arns" {
  description = "AWS Secrets Manager ARNs holding each agent's API key, keyed by agent name."
  value       = { for name, s in aws_secretsmanager_secret.agent : name => s.arn }
}

output "agent_secret_names" {
  description = "AWS Secrets Manager secret names (remoteKey paths) per agent."
  value       = local.agent_aws_keys
}

output "gateway_credential_secrets" {
  description = "Kubernetes Secret name each gateway reads its API key from, keyed by agent name."
  value       = { for name, _ in var.agents : name => "${name}-credential" }
}

output "anchor_api_base_url" {
  description = "Resolved Anchor API base URL the gateways connect to."
  value       = local.anchor_api_base_url
}

output "agents_namespace" {
  description = "Namespace the agent gateways run in."
  value       = var.agents_namespace
}
