# Connectivity / provider config (lives in the caller, not the module).
variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type    = string
  default = ""
}

variable "aws_region" {
  type = string
}

# Anchor control plane.
variable "anchor_url" {
  type        = string
  description = "Anchor base URL WITHOUT /api/v1, e.g. https://anchor.example.com."
}

variable "register_agents_in_anchor" {
  type    = bool
  default = true
}

variable "anchor_admin_email" {
  type    = string
  default = ""
}

variable "anchor_admin_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "anchor_admin_token" {
  type      = string
  default   = ""
  sensitive = true
}

# Passed through to the module.
variable "environment" {
  type = string
}

variable "external_secrets" {
  type = object({
    secret_store_name = optional(string, "aws-secretsmanager")
    secret_store_kind = optional(string, "ClusterSecretStore")
    refresh_interval  = optional(string, "1h")
  })
  default = {}
}

variable "agents" {
  type = map(object({
    description            = optional(string, "")
    image                  = optional(string)
    replicas               = optional(number, 1)
    agent_version          = optional(string, "0.1.0")
    allowed_resource_types = optional(list(string), ["configuration", "variable"])
    allow_secret_values    = optional(bool, false)
    expires_in_days        = optional(number, 90)
    mcp_enabled            = optional(bool, false)
    cache_ttl_ms           = optional(number, 30000)
    heartbeat_interval_ms  = optional(number, 60000)
    log_level              = optional(string, "info")
    labels                 = optional(map(string), {})
    scopes = optional(list(object({
      project_id     = string
      environment_id = optional(string)
    })), [])
    api_key        = optional(string)
    aws_remote_key = optional(string)
  }))
  default = {}
}
