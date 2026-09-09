# GitHub Environments

This folder documents the [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
referenced by the workflows in [.github/workflows/](../.github/workflows/). Each environment name below
must exist under the repo's **Settings > Environments** in GitHub, with the listed secrets configured there.

Note: GitHub Environment secrets are write-only — their values can never be read back via the UI or
API, so these subfolders record which secret/variable *names* each environment must provide, not values.

| Environment | Required secrets |
|---|---|---|
| [dev](dev/) | `OIDC_ROLE_ARN` |
| [staging](staging/) | `OIDC_ROLE_ARN` |
| [prod](prod/) | `OIDC_ROLE_ARN` |
| [workspaces](workspaces/) |  `OIDC_ROLE_ARN` |
| [ad](ad/) | `OIDC_ROLE_ARN` |

`terraform-plan.yaml` additionally accepts an optional `TF_VAR_EXTRAS` secret (a JSON map injected as
`TF_VAR_*` environment variables) and expects a `<environment>.tfvars` file in the caller's working
directory — neither exists yet in this repo.
