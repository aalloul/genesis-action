# genesis-infra-api

Renders Terraform configuration for a new organization/data product or for new resources in a data product using the `genesis-api` Docker image, then applies it against GCP. After a successful apply, Terraform outputs are optionally stored as GitHub Actions variables and secrets for use by downstream workflows.

## Prerequisites

- The calling repository must be added to the `genesis-api` GHCR package access list by your Genesis administrator.
- A GCP seed project and seed service account must exist with permissions to create projects under the target folder.
- Workload Identity Federation must be configured between your GitHub Actions workflow and the seed service account.
- To store Terraform outputs as GitHub variables/secrets, the GitHub environment named after the `ENVIRONMENT` key must already exist in the repository settings.

## Usage

```yaml
jobs:
  create-infra:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: read
      id-token: write   # required for WIF authentication

    steps:
      - uses: actions/checkout@v4

      - uses: aalloul/genesis-action/genesis-infra-api@v1
        with:
          action: create-basic-infra
          config_yml_file: genesis_config.yml
          genesis_version: "1.0.0"
          debug: false
          run_terraform_apply: true
          env_vars: ${{ toJSON(vars) }}
          secrets: ${{ toJSON(secrets) }}
```

`vars` and `secrets` are the repository/environment variables and secrets configured in your GitHub repo settings — dump them wholesale rather than wiring each value into its own action input. The action reads the well-known keys it needs (see [Configuration keys](#configuration-keys)) out of the merged object; anything else present is ignored. If a key exists in both `env_vars` and `secrets`, the `secrets` value wins.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `action` | yes | — | Genesis action to run. `create-basic-infra`, `create-data-product` or `provision-resources`. |
| `config_yml_file` | yes | — | Path to `genesis_config.yml`, relative to the repository root. |
| `genesis_version` | yes | — | `genesis-api` image tag, e.g. `1.2.3`. |
| `debug` | no | `false` | Upload generated Terraform files as a workflow artifact. |
| `run_terraform_apply` | no | `true` | Set to `false` to run plan only (useful for dry-runs). |
| `env_vars` | no | `{}` | JSON object of non-secret configuration, e.g. `${{ toJSON(vars) }}`. |
| `secrets` | no | `{}` | JSON object of sensitive configuration, e.g. `${{ toJSON(secrets) }}`. Values are masked in logs and take precedence over `env_vars` on key collisions. |

## Configuration keys

These are the keys the action looks for inside the merged `env_vars`/`secrets` object. Key names are exact — they don't need to match your GitHub vars/secrets names, but the JSON object you pass in must contain them under these names for the action to pick them up. None of the keys below are hard-validated by this action: whether a given key is actually needed depends on the `action` you're running (e.g. org/folder-level keys are irrelevant for `provision-resources`, which only touches an existing data product) — that's enforced by the `genesis-api` image itself, not by this action.

| Key | Default | Description |
|-----|---------|-------------|
| `FOLDER_ID` | — | GCP folder ID under which the new project is created. |
| `CLOUD_PROVIDER` | — | Cloud provider. Currently only `gcp` is supported. |
| `GCP_REGION` | — | GCP region, e.g. `europe-west1`. |
| `GCP_ZONE` | — | GCP zone, e.g. `europe-west1-b`. |
| `ORGANIZATION_SHORT_NAME` | — | Short organisation name used as a resource prefix. |
| `GCP_PROJECT_ID` | — | The GCP project ID to deploy to. |
| `IMPERSONATE_SERVICE_ACCOUNT` | — | Email of the SA to impersonate for Terraform operations. |
| `BILLING_ACCOUNT` | — | GCP billing account ID to attach to the new project. |
| `GCP_SEED_PROJECT` | — | GCP seed project used for quota and impersonation. |
| `GCP_SERVICE_ACCOUNT` | — | GCP service account email for Terraform operations. |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | — | Full WIF provider resource name. |
| `GITHUB_REPOSITORY_OWNER` | — | GitHub user or organisation that owns the calling repository. |
| `VPCSC_PERIMETER_NAME` | — | Name of the VPC Service Controls perimeter to add the project to. |
| `ENVIRONMENT` | — | Deployment environment, e.g. `dev`, `staging`, `prod`. |
| `TERRAFORM_BUCKET` | — | GCS bucket for Terraform remote state. |
| `ORGANIZATION_NAME` | — | Full organisation name (used for display purposes). |
| `ORGANIZATION_ID` | — | GCP organisation ID. |
| `REPO_ADMIN_TOKEN` | — | GitHub Personal Access Token used to create/update GitHub Actions variables and secrets after apply. Required if `run_terraform_apply` is `true`. See [required PAT permissions](#required-pat-permissions) below. |
| `GHCR_TOKEN` | `github.token` | GitHub token with `packages:read`. Used to pull the genesis-api image from GHCR. |
| `USERNAME` | `github.actor` | GitHub username associated with `GHCR_TOKEN`. |
| `GITHUB_REPO_NAME` | — | Name of the repo where environment variables & secrets will be stored. If omitted, read from the Terraform output key `github_repo_name`. |
| `TERRAFORM_OUTPUT_DIR` | `terraform_output_dir` | Directory (relative to repo root) where generated Terraform files are written. |
| `TERRAFORM_VERSION` | `1.14.8` | Terraform version to install. |

## Storing Terraform outputs as GitHub variables and secrets

After `terraform apply`, the action picks a mapping file (located in this directory) based on `action` and pushes Terraform output values into GitHub Actions variables and secrets: `base_infra_mappings.json` for `create-basic-infra`, `data_product_creation_mappings.json` for `create-data-product`, and `data_product_provision_resources_mappings.json` for `provision-resources`.

The mapping file is a JSON file with the following structure:

```json
{
  "secrets": [
    {
      "tf_key": "composer_service_account",
      "gh_name": "COMPOSER_SA",
      "env_scoped": true
    }
  ],
  "variables": [
    {
      "tf_key": "project_id",
      "gh_name": "GCP_PROJECT_ID",
      "env_scoped": false
    },
    {
      "tf_key": "composer_url",
      "gh_name": "COMPOSER_URL",
      "env_scoped": true
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `tf_key` | Key name from `terraform output -json`. |
| `gh_name` | GitHub variable or secret name to create/update. |
| `env_scoped` | `true` → stored under the GitHub environment named by the `ENVIRONMENT` key. `false` → stored at repository level. |

Entries with an empty `tf_key` are skipped, so the default file is a no-op.

### Required PAT permissions

Variables and secrets are written using the `REPO_ADMIN_TOKEN` key, which must be a GitHub Personal Access Token with the following repository permissions on the target repository:

| Permission | Level |
|------------|-------|
| Environments | Read and write |
| Secrets | Read and write |
| Variables | Read and write |

> Note: the built-in `GITHUB_TOKEN` cannot be used here because it does not support environment-scoped variables and secrets via the REST API.

The target GitHub environment (matching the `ENVIRONMENT` key) must already exist in the repository settings before environment-scoped variables or secrets can be written.

## What the action does

1. Resolves configuration by merging `env_vars` and `secrets`, validating required keys, and masking secret values in logs.
2. Logs in to GHCR using the `GHCR_TOKEN`/`USERNAME` keys.
3. Runs the `genesis-api` Docker image, which generates Terraform files from `genesis_config.yml` into `TERRAFORM_OUTPUT_DIR`.
4. Optionally uploads the generated files as a workflow artifact (`debug: true`).
5. Runs `terraform init`, `terraform validate`, and `terraform plan`.
6. If `run_terraform_apply` is `true`, runs `terraform apply`.
7. If `run_terraform_apply` is `true`, picks the mapping file for `action` and stores configured Terraform outputs as GitHub variables and secrets.
