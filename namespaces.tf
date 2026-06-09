# The agents namespace (where gateways run). The operator install creates
# anchor-system itself, so we only manage the agents namespace here.
resource "kubernetes_namespace" "agents" {
  count = var.manage_namespaces ? 1 : 0

  metadata {
    name   = var.agents_namespace
    labels = local.common_labels
  }
}

# For a private gateway image: attach an existing imagePullSecret to the agents
# namespace's default ServiceAccount, which the operator-created gateway pods
# inherit (the AnchorAgent CRD has no imagePullSecrets field of its own).
resource "kubernetes_default_service_account" "agents" {
  count = var.image_pull_secret != "" ? 1 : 0

  metadata {
    namespace = var.agents_namespace
  }

  image_pull_secret {
    name = var.image_pull_secret
  }

  depends_on = [kubernetes_namespace.agents]
}
