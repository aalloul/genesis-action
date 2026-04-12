> **License:** [Elastic License 2.0](./LICENSE) — source available, commercial use requires a valid access grant.

# genesis-action

Public GitHub Actions for the Genesis API. Each action lives in its own subdirectory.

| Action | Description |
|---|---|
| [`authenticate-with-gcp`](./authenticate-with-gcp/) | Authenticates the workflow with GCP using Workload Identity Federation (WIF) |
| [`create-basic-infra`](genesis-infra-api/) | Renders Terraform files for a new organisation from a `genesis_config.yml` |

## `authenticate-with-gcp`

Authenticates the workflow with GCP using Workload Identity Federation.

### Prerequisites

Your GCP project must have a Workload Identity Pool and Provider configured for GitHub Actions, and the service account must be granted the `roles/iam.workloadIdentityUser` role for the relevant GitHub repository.

If you need help setting this up, check the documentation [here](https://github.com/google-github-actions/auth?tab=readme-ov-file)

### Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # required for WIF token exchange
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: aalloul/genesis-action/authenticate-with-gcp@v1
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider
          service_account: my-sa@my-project.iam.gserviceaccount.com
          gcp_project: my-gcp-project-id
```

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `workload_identity_provider` | ✅ | — | Full WIF provider resource name |
| `service_account` | ✅ | — | GCP service account email to impersonate |
| `gcp_project` | ✅ | — | GCP project ID to authenticate against |
| `token_format` | ❌ | `access_token` | Token format: `access_token` or `id_token` |
| `audience` | ❌ | `""` | Token audience (only relevant for `id_token` format) |

### Outputs

| Output | Description |
|---|---|
| `access_token` | The GCP access token (populated when `token_format` is `access_token`) |

---

## `create-basic-infra`

### Prerequisites

Your repository must be added to the **genesis-api GHCR package access list** by your Genesis administrator before any action will work. Contact your administrator with your repository name (`your-org/your-repo`).

### Usage

```yaml
jobs:
  create-infra:
    runs-on: ubuntu-latest
    permissions:
      contents: write   # to commit the rendered files, if needed
      packages: read    # required to pull the genesis-api Docker image

    steps:
      - uses: actions/checkout@v4

      - uses: aalloul/genesis-action/create-basic-infra@v1
        with:
          cfg: genesis_config.yml        # path to your config, relative to repo root
          output_dir: terraform-out      # where rendered .tf files will be written
```

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `cfg` | ✅ | — | Path to the genesis config YAML file, relative to the repository root |
| `output_dir` | ✅ | — | Directory to write rendered Terraform files into |
| `token` | ❌ | `github.token` | GitHub token with `packages:read`. Defaults to the workflow's own `GITHUB_TOKEN` |
| `version` | ❌ | `latest` | Specific genesis-api image version to pin to (e.g. `1.2.3`) |

### Pinning to a specific version

```yaml
- uses: aalloul/genesis-action/create-basic-infra@v1
  with:
    cfg: genesis_config.yml
    output_dir: terraform-out
    version: '1.2.3'   # pin to an exact release for reproducible builds
```

