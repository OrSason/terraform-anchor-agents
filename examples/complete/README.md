# Complete example

A turnkey root that configures every provider the module needs — including
logging in to Anchor and feeding the JWT to the `restapi` provider — then calls
the module. This is the pattern to copy into your infra repo.

```bash
cp terraform.tfvars.example terraform.tfvars   # edit it
export TF_VAR_anchor_admin_password='…'        # keep secrets out of the file
terraform init
terraform plan
terraform apply
```

When consuming the published module from your own infra repo, replace the local
`source = "../../"` with the released module, e.g.:

```hcl
module "anchor_agents" {
  source = "github.com/OrSason/terraform-anchor-agents?ref=v0.1.0"
  # ...same inputs...
}
```
