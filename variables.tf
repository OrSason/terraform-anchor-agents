# NOTE: This is a reusable module — it does NOT configure providers. The caller
# configures kubernetes, kubectl, aws, and restapi (see examples/complete). The
# variables here are the module's behavioral inputs only.

# ---------------------------------------------------------------------------
# Target environment (required — drives secret paths, labels, namespaces)
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Target environment. Used in AWS secret paths and resource labels."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "staging", "qa", "uat", "prod", "production", "development"], lower(var.environment))
    error_message = "environment must be one of: dev, stg, staging, qa, uat, prod, production, development."
  }
}

# ---------------------------------------------------------------------------
# Anchor control plane (gateway upstream + registration target)
# ---------------------------------------------------------------------------

variable "anchor_url" {
  description = "Anchor base URL WITHOUT the /api/v1 suffix, e.g. https://anchor.example.com. Used as the gateway upstream; the caller's restapi provider should point at the same host."
  type        = string
}

variable "register_agents_in_anchor" {
  description = <<-EOT
    When true, the module calls Anchor's management API (via the caller's
    configured restapi provider) to create each service agent and captures the
    returned one-time API key. When false, you must supply each agent's
    `api_key` (or rely on an already-populated AWS secret).
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# What to install (toggles)
# ---------------------------------------------------------------------------

variable "install_operator" {
  description = "Install the anchor-agent-operator (CRD + RBAC + namespace + Deployment) from the bundled manifests."
  type        = bool
  default     = true
}

variable "manage_namespaces" {
  description = "Let this module create the agents namespace (the operator install creates anchor-system)."
  type        = bool
  default     = true
}

variable "install_backend_rbac" {
  description = "Install read-only RBAC so Anchor's backend ServiceAccount can observe gateway pods/logs/events."
  type        = bool
  default     = true
}

variable "backend_rbac_cluster_wide" {
  description = "If true the observer RBAC is a ClusterRole/Binding (agents across many namespaces); if false a namespaced Role/Binding in the agents namespace."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Namespaces + operator
# ---------------------------------------------------------------------------

variable "agents_namespace" {
  description = "Namespace where agent gateways run (matches ANCHOR_AGENTS_NAMESPACE)."
  type        = string
  default     = "agents"
}

variable "operator_namespace" {
  description = "Namespace the operator runs in (created by the operator manifests)."
  type        = string
  default     = "anchor-system"
}

variable "operator_manifest_dir" {
  description = "Directory containing the operator's crd.yaml / rbac.yaml / operator.yaml. Empty = the module's bundled manifests/ directory."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Anchor backend identity (for observer RBAC)
# ---------------------------------------------------------------------------

variable "anchor_backend_namespace" {
  description = "Namespace where the Anchor backend runs (the ServiceAccount that observes gateways lives here)."
  type        = string
  default     = "anchor-system"
}

variable "anchor_backend_service_account" {
  description = "Anchor backend ServiceAccount name granted read-only access to gateway pods."
  type        = string
  default     = "anchor-backend"
}

# ---------------------------------------------------------------------------
# Gateway image + pull secret
# ---------------------------------------------------------------------------

variable "gateway_image" {
  description = "Default Anchor Agent Gateway image (overridable per agent)."
  type        = string
  default     = "ghcr.io/orsason/anchor-agent-gateway:latest"
}

variable "image_pull_secret" {
  description = "Optional name of an imagePullSecret (in the agents namespace) for a private gateway image. Empty = none."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# External Secrets Operator (credential delivery)
# ---------------------------------------------------------------------------

variable "external_secrets" {
  description = "External Secrets Operator wiring used to sync agent API keys from AWS Secrets Manager into k8s Secrets."
  type = object({
    secret_store_name = optional(string, "aws-secretsmanager")
    secret_store_kind = optional(string, "ClusterSecretStore")
    refresh_interval  = optional(string, "1h")
  })
  default = {}
}

variable "aws_secret_name_prefix" {
  description = "Prefix for the AWS Secrets Manager secret name per agent. Final path: <prefix>/<agent>. Empty = anchor/<environment>/agents."
  type        = string
  default     = ""
}

variable "create_secrets" {
  description = <<-EOT
    Whether this module creates+manages each agent's AWS Secrets Manager secret
    (and its version). Set false to "bring your own" secret created out of band
    — e.g. a cross-region primary/replica secret that this module's single-region
    aws provider cannot manage (tagging a replica is rejected by AWS). When false,
    the secret must already exist at <prefix>/<agent>; the ExternalSecret/AnchorAgent
    still reference it by name, so credential delivery is unaffected.
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# The agents
# ---------------------------------------------------------------------------

variable "agents" {
  description = <<-EOT
    Map of agents to deploy, keyed by agent name (used as the k8s/CR name —
    must be RFC1123: lowercase alphanumeric + '-'). Each agent is registered in
    Anchor (when enabled), its key stored in AWS Secrets Manager, synced via an
    ExternalSecret, and reconciled into a gateway by the operator.
  EOT

  type = map(object({
    description            = optional(string, "")
    image                  = optional(string) # falls back to var.gateway_image
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

    # Scope grants. environment_id = null grants the whole project.
    scopes = optional(list(object({
      project_id     = string
      environment_id = optional(string)
    })), [])

    # Used only when register_agents_in_anchor = false: supply a pre-issued key.
    api_key = optional(string)

    # Override the AWS Secrets Manager path (defaults to <aws_secret_name_prefix>/<name>).
    aws_remote_key = optional(string)
  }))

  default = {}
}
