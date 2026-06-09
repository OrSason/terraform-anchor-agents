# terraform-anchor-agents

A reusable Terraform module that deploys **everything needed for Anchor service
agents** across both planes:

- **Control plane** — registers each agent in Anchor (`POST /api/v1/service-agents`)
  and captures its one-time API key.
- **Data plane** — stores that key in AWS Secrets Manager, syncs it into a
  Kubernetes Secret via External Secrets, and creates an `AnchorAgent` custom
  resource that the operator reconciles into a gateway Deployment/Service/ConfigMap.

```
var.agents["release-bot"]
  └─ restapi_object.agent           POST /service-agents → { apiKey }   (control plane)
  └─ aws_secretsmanager_secret      anchor/<env>/agents/release-bot = { apiKey }
  └─ ExternalSecret                 AWS SM → Secret release-bot-credential
  └─ AnchorAgent (CR)               operator → release-bot-gateway Deployment+Service+ConfigMap
```

Plus, once per cluster: the **operator** (CRD + RBAC + `anchor-system` ns +
Deployment, from the bundled `manifests/`), the **agents namespace**, and the
**backend observer RBAC**.

## This is a reusable module — the caller configures providers

The module contains **no `provider` blocks** (required for a published module).
The caller configures `kubernetes`, `kubectl`, `aws`, and `restapi`, and performs
the Anchor login. [`examples/complete`](./examples/complete) is a copy-paste root
that does all of it.

```hcl
module "anchor_agents" {
  source = "github.com/OrSason/terraform-anchor-agents?ref=v0.1.0"

  environment = "prod"
  anchor_url  = "https://anchor.example.com"

  agents = {
    release-bot = {
      allowed_resource_types = ["configuration", "variable"]
      scopes                 = [{ project_id = "1111-…" }]
    }
  }
}
```

## What it manages (all toggleable)

| Toggle | Default | Creates |
|---|---|---|
| `install_operator` | `true` | `AnchorAgent` CRD, operator SA/ClusterRole/Binding, `anchor-system` ns, operator Deployment (from bundled `manifests/`) |
| `manage_namespaces` | `true` | the `agents` namespace |
| `install_backend_rbac` | `true` | read-only Role/Binding (or ClusterRole/Binding) for Anchor's backend SA |
| `register_agents_in_anchor` | `true` | each agent in Anchor + captures its API key |
| `var.agents` | `{}` | per agent: AWS SM secret, ExternalSecret, `AnchorAgent` CR |

## Prerequisites

- A reachable cluster where the **External Secrets Operator** is installed with a
  `(Cluster)SecretStore` pointing at AWS Secrets Manager.
- AWS credentials for the `aws` provider.
- An Anchor super-admin JWT, or login credentials, when
  `register_agents_in_anchor = true` (handled in the caller — see the example).
- The gateway image must be pullable; for a private image set `image_pull_secret`.

## Credential model (AWS Secrets Manager + External Secrets)

1. The key is captured from Anchor at registration (returned once, on create),
2. written as `{ "apiKey": "<key>" }` to `anchor/<environment>/agents/<name>` in AWS SM,
3. synced by the ExternalSecret into the `<name>-credential` Kubernetes Secret,
4. referenced by `AnchorAgent.spec.credentialSecretRef`.

> **State note:** because Anchor only returns the key on create, Terraform holds
> it in state long enough to write it to AWS SM. Keep your state backend
> encrypted (e.g. S3 + KMS). To keep the key out of Terraform entirely, set
> `register_agents_in_anchor = false` and pre-create the AWS secret out-of-band.

## Bundled operator manifests

`manifests/{crd,rbac,operator}.yaml` are copied from the Anchor repo's
`operator/deploy/` so the module is **self-contained** (no path dependency on the
product repo). When the operator's manifests change upstream, re-sync them:

```bash
cp ../Anchor/operator/deploy/{crd,rbac,operator}.yaml manifests/
```

(Point `operator_manifest_dir` at another directory to override the bundle.)

## Publishing as its own public repo

This directory is laid out to become a standalone repo (`.tf` at the root,
`examples/`, `manifests/`). To extract:

```bash
# from a fresh clone of this directory's contents
git init && git add . && git commit -m "init terraform-anchor-agents"
gh repo create OrSason/terraform-anchor-agents --public --source=. --push
git tag v0.1.0 && git push --tags
```

Licensed under [MIT](./LICENSE). Naming follows the registry convention
`terraform-<provider>-<name>`; you can later publish it to the Terraform Registry.

## Notes & caveats

- **Scope edits after creation** are best made in the Anchor UI/API — the
  registration body is `ignore_changes`d to avoid perpetual diffs. To force a
  re-register: `terraform taint 'module.anchor_agents.restapi_object.agent["<name>"]'`.
- `allowedProjectIds/allowedEnvironmentIds` on the gateway are derived from each
  agent's `scopes` as defense-in-depth allow-lists.
- `kubectl_manifest` (server-side apply) is used for the CRD and all custom
  resources so the CRD and the `AnchorAgent` CRs apply in one run.
- Agent map keys are the agent/CR/Secret name → must be RFC1123 (lowercase
  alphanumeric and `-`).
