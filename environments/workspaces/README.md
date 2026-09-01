# workspaces

GitHub Environment name: `workspaces`

## Used by
- `.github/workflows/test-oidc-creds.yaml` — job `test-workspaces`, hardcoded `aws-region: us-east-1`

## Required secrets (configure under Settings > Environments > workspaces)
- `OIDC_ROLE_ARN` — IAM role ARN assumed via GitHub OIDC for AWS access in this environment.

Not currently referenced by `terraform-plan.yaml`, so no `.tfvars` file or `TF_VAR_EXTRAS` secret is expected yet.
