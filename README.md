> **License:** [Elastic License 2.0](./LICENSE) — source available, commercial use requires a valid access grant.

# genesis-action

Public GitHub Actions for the Genesis API. Each action lives in its own subdirectory.

| Action | Description |
|---|---|
| [`create-basic-infra`](./create-basic-infra/) | Renders Terraform files for a new organisation from a `genesis_config.yml` |

## Prerequisites

Your repository must be added to the **genesis-api GHCR package access list** by your Genesis administrator before any action will work. Contact your administrator with your repository name (`your-org/your-repo`).

## `create-basic-infra`

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

