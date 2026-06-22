terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Core typed k8s objects: namespaces, ServiceAccounts, RBAC, the operator Deployment.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }

    # Server-side apply of CRDs and Custom Resources (AnchorAgent, ExternalSecret).
    # Unlike kubernetes_manifest, kubectl_manifest does NOT need the CRD schema to
    # exist at plan time, so we can install the CRD and create CRs in one apply.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    # AWS Secrets Manager: where each agent's API key is stored at rest.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Calls Anchor's management API to register each service agent and capture
    # its one-time API key. Configured by the caller (see examples/complete).
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

# Providers are intentionally NOT configured in this module — the caller supplies
# configured kubernetes, kubectl, aws, and restapi providers. See examples/complete
# for a turnkey root that logs in to Anchor and wires all four.
