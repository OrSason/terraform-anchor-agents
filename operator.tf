# Install the anchor-agent-operator from its shipped manifests
# (operator/deploy/{crd,rbac,operator}.yaml). Each multi-doc file is split into
# individual documents and applied server-side via kubectl_manifest, which does
# NOT require the AnchorAgent CRD schema at plan time. sample-anchoragent.yaml is
# deliberately excluded — agents are created from var.agents, not the sample.

locals {
  operator_manifest_files = var.install_operator ? toset([
    "${local.operator_manifest_dir}/crd.yaml",
    "${local.operator_manifest_dir}/rbac.yaml",
    "${local.operator_manifest_dir}/operator.yaml",
  ]) : toset([])
}

data "kubectl_file_documents" "operator" {
  for_each = local.operator_manifest_files
  content  = file(each.value)
}

locals {
  # Merge every document across the three files into one map keyed by
  # apiVersion/kind/namespace/name (stable across plans).
  operator_documents = merge([
    for f, doc in data.kubectl_file_documents.operator : doc.manifests
  ]...)
}

resource "kubectl_manifest" "operator" {
  for_each = local.operator_documents

  yaml_body         = each.value
  server_side_apply = true
  wait              = true
}
