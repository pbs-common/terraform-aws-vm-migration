# prod

GitHub Environment name: `prod`

## Used by
- `.github/workflows/test-oidc-creds.yaml` — job `test-prod`, hardcoded `aws-region: us-east-1`
- `.github/workflows/terraform-plan.yaml` — reusable workflow, invoked with `environment: prod` by a caller workflow (region/working-directory/tfvars supplied by the caller)

## Required secrets (configure under Settings > Environments > prod)
- `OIDC_ROLE_ARN` — IAM role ARN assumed via GitHub OIDC for AWS access in this environment.

## Optional secrets (terraform-plan.yaml only)
- `TF_VAR_EXTRAS` — JSON map of extra `TF_VAR_*` values to inject, e.g. `{"foo":"bar"}`.

## Expected file (not present yet)
- `prod.tfvars` in the Terraform working directory passed to `terraform-plan.yaml`.

Consider adding required reviewers / a deployment branch policy to this environment in GitHub given it targets production.
