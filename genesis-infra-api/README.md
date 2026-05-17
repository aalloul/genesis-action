# genesis-infra-api

Renders Terraform configuration for a new organization/data product or for new resources in a data product using the `genesis-api` Docker image, then applies it against GCP. After a successful apply, Terraform outputs are optionally stored as GitHub Actions variables and secrets for use by downstream workflows.

## Prerequisites

- The calling repository must be added to the `genesis-api` GHCR package access list by your Genesis administrator.
- A GCP seed project and seed service account must exist with permissions to create projects under the target folder.
- Workload Identity Federation must be configured between your GitHub Actions workflow and the seed service account.
- To store Terraform outputs as GitHub variables/secrets, the GitHub environment named after `inputs.environment` must already exist in the repository settings.

## Usage

```yaml
jobs:
  create-infra:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: read
      id-token: write   # required for WIF authentication
      variables: write  # required to store Terraform outputs as variables
      secrets: write    # required to store Terraform outputs as secrets

    steps:
      - uses: actions/checkout@v4

      - uses: aalloul/genesis-action/genesis-infra-api@v1
        with:
          action: create-basic-infra
          environment: dev
          config_yml_file: genesis_config.yml
          genesis_version: "1.0.0"
          terraform_bucket: my-terraform-state-bucket
          github_repository_owner: my-org
          folder_id: "123456789"
          cloud_provider: gcp
          gcp_region: europe-west1
          gcp_zone: europe-west1-b
          organization_short_name: myorg
          organization_name: My Organisation
          organization_id: "987654321"
          seed_project_id: my-seed-project
          seed_service_account: seed-sa@my-seed-project.iam.gserviceaccount.com
          billing_account: ABCDEF-123456-ABCDEF
          gcp_seed_project: my-seed-project
          gcp_service_account: terraform-sa@my-seed-project.iam.gserviceaccount.com
          gcp_workload_identity_provider: projects/123/locations/global/workloadIdentityPools/my-pool/providers/my-provider
          vpcsc_perimeter_name: my_perimeter
          mapping_type: base_infra_mappings
```

## Inputs

### Action control

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `action` | yes | — | Genesis action to run. `create-basic-infra` or `create-data-product`. |
| `environment` | yes | — | Deployment environment, e.g. `dev`, `staging`, `prod`. |
| `run_terraform_apply` | no | `true` | Set to `false` to run plan only (useful for dry-runs). |
| `debug` | no | `false` | Upload generated Terraform files as a workflow artifact. |

### GitHub authentication

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `token` | no | `github.token` | GitHub token with `packages:read`. Used to pull the genesis-api image from GHCR and to set repository variables/secrets after apply. |
| `username` | no | `github.actor` | GitHub username associated with `token`. |

### Genesis configuration

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `config_yml_file` | yes | — | Path to `genesis_config.yml`, relative to the repository root. |
| `genesis_version` | yes | — | `genesis-api` image tag, e.g. `1.2.3`. |

### Terraform

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `terraform_bucket` | yes | — | GCS bucket for Terraform remote state. |
| `terraform_output_dir` | no | `terraform_output_dir` | Directory (relative to repo root) where generated Terraform files are written. |
| `terraform_version` | no | `1.14.8` | Terraform version to install. |

### GCP & organisation

| Input | Required | Description |
|-------|----------|-------------|
| `cloud_provider` | yes | Cloud provider. Currently only `gcp` is supported. |
| `folder_id` | yes | GCP folder ID under which the new project is created. |
| `organization_id` | yes | GCP organisation ID. |
| `organization_name` | yes | Full organisation name (used for display purposes). |
| `organization_short_name` | yes | Short organisation name used as a resource prefix. |
| `gcp_region` | yes | GCP region, e.g. `europe-west1`. |
| `gcp_zone` | yes | GCP zone, e.g. `europe-west1-b`. |
| `seed_project_id` | yes | GCP project ID of the seed project. |
| `seed_service_account` | yes | Email of the seed service account used to create resources. |
| `gcp_seed_project` | yes | GCP seed project used for quota and impersonation. |
| `gcp_service_account` | yes | Service account email used by Terraform. |
| `gcp_workload_identity_provider` | yes | Full WIF provider resource name. |
| `billing_account` | yes | GCP billing account ID to attach to the new project. |
| `vpcsc_perimeter_name` | yes | Name of the VPC Service Controls perimeter to add the project to. |
| `github_repository_owner` | yes | GitHub user or organisation that owns the calling repository. |

## Storing Terraform outputs as GitHub variables and secrets

After `terraform apply`, the action reads the file indicated in `$mapping_type` (located in this directory) and pushes Terraform output values into GitHub Actions variables and secrets.

Possible values for `$mapping_type` are  `base_infra_mappings` that will store the base infrastructure outputs (project ID and name) and `resource_mappings` that will store data product-specific outputs (e.g. BigQuery dataset name, Pub/Sub topic name).

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
| `env_scoped` | `true` → stored under the GitHub environment named by `inputs.environment`. `false` → stored at repository level. |

Entries with an empty `tf_key` are skipped, so the default file is a no-op.

The calling workflow must declare the following permissions for this step to succeed:

```yaml
permissions:
  variables: write
  secrets: write
```

The target GitHub environment (matching `inputs.environment`) must already exist in the repository settings before environment-scoped variables or secrets can be written.

## What the action does

1. Logs in to GHCR using `token` and `username`.
2. Runs the `genesis-api` Docker image, which generates Terraform files from `genesis_config.yml` into `terraform_output_dir`.
3. Optionally uploads the generated files as a workflow artifact (`debug: true`).
4. Runs `terraform init`, `terraform validate`, and `terraform plan`.
5. If `run_terraform_apply` is `true`, runs `terraform apply`.
6. If `run_terraform_apply` is `true`, reads `${mappings_type}.json` and stores configured Terraform outputs as GitHub variables and secrets.
