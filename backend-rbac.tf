# Read-only RBAC so Anchor's backend ServiceAccount can observe agent gateway
# pods/logs/events/deployments and surface live status in the UI.
# Namespaced Role by default; promote to cluster-wide when agents span namespaces.

locals {
  observer_rules = [
    {
      api_groups = [""]
      resources  = ["pods", "pods/log", "events"]
      verbs      = ["get", "list", "watch"]
    },
    {
      api_groups = ["apps"]
      resources  = ["deployments", "replicasets"]
      verbs      = ["get", "list", "watch"]
    },
  ]

  make_ns_rbac      = var.install_backend_rbac && !var.backend_rbac_cluster_wide
  make_cluster_rbac = var.install_backend_rbac && var.backend_rbac_cluster_wide
}

resource "kubernetes_role" "observer" {
  count = local.make_ns_rbac ? 1 : 0

  metadata {
    name      = "anchor-agent-observer"
    namespace = var.agents_namespace
    labels    = local.common_labels
  }

  dynamic "rule" {
    for_each = local.observer_rules
    content {
      api_groups = rule.value.api_groups
      resources  = rule.value.resources
      verbs      = rule.value.verbs
    }
  }

  depends_on = [kubernetes_namespace.agents]
}

resource "kubernetes_role_binding" "observer" {
  count = local.make_ns_rbac ? 1 : 0

  metadata {
    name      = "anchor-agent-observer"
    namespace = var.agents_namespace
    labels    = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.observer[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.anchor_backend_service_account
    namespace = var.anchor_backend_namespace
  }
}

resource "kubernetes_cluster_role" "observer" {
  count = local.make_cluster_rbac ? 1 : 0

  metadata {
    name   = "anchor-agent-observer"
    labels = local.common_labels
  }

  dynamic "rule" {
    for_each = local.observer_rules
    content {
      api_groups = rule.value.api_groups
      resources  = rule.value.resources
      verbs      = rule.value.verbs
    }
  }
}

resource "kubernetes_cluster_role_binding" "observer" {
  count = local.make_cluster_rbac ? 1 : 0

  metadata {
    name   = "anchor-agent-observer"
    labels = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.observer[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.anchor_backend_service_account
    namespace = var.anchor_backend_namespace
  }
}
