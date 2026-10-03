> **License:** [Elastic License 2.0](./LICENSE) — source available, commercial use requires a valid access grant.

# genesis-action

Public GitHub Actions for the Genesis API. Each action lives in its own subdirectory.

| Action | Description |
|---|---|
| [`authenticate-with-gcp`](./authenticate-with-gcp/) | Authenticates the workflow with GCP using Workload Identity Federation (WIF) |
| [`create-basic-infra`](genesis-infra-api/) | Renders Terraform files for a new organisation from a `genesis_config.yml` |
| [`semantic-release`](./semantic-release/) | Computes the next semantic version from commit messages and publishes a GitHub release |
| [`build-and-push-docker-image`](./build-and-push-docker-image/) | Builds a data product's (optional) Docker image and pushes it to its Artifact Registry repository |

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
| `service_account` | ❌ | `""` | GCP service account email to impersonate. Empty = direct WIF (e.g. Terraform with `impersonate_service_account`) |
| `gcp_project` | ✅ | — | GCP project ID to authenticate against |
| `token_format` | ❌ | `access_token` when `service_account` is set | `access_token` or `id_token`. Requires `service_account` |
| `audience` | ❌ | `""` | Token audience (only relevant for `id_token` format) |

### Outputs

| Output | Description |
|---|---|
| `access_token` | The GCP access token (populated when impersonating with `token_format` `access_token`) |

---

## `create-basic-infra`

### Prerequisites

Your repository must be added to the **genesis-api GHCR package access list** by your Genesis administrator before any action will work. Contact your administrator with your repository name (`your-org/your-repo`).

#### `repo_admin_token` — required PAT permissions

The action uses `repo_admin_token` both to store Terraform outputs as GitHub secrets/variables and to let Terraform create and configure GitHub repositories. The token must be able to act on repositories that do not exist yet at the time the workflow runs.

**Fine-grained PAT (recommended)**

Set repository access to **All repositories** in the target organisation (specific-repo access will cause 403 errors on newly created repos). Grant the following permissions:

| Permission | Level |
|---|---|
| Administration | Read and write |
| Contents | Read and write |
| Environments | Read and write |
| Secrets | Read and write |
| Variables | Read and write |
| Members | Read and write |

**Classic PAT**

Grant the `repo` scope (full) and `admin:org` (for team-repository management).

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


---

## `semantic-release`

Runs [semantic-release](https://github.com/semantic-release/semantic-release) and exposes the computed version. Versions are derived from [Conventional Commits](https://www.conventionalcommits.org) (`feat:` → minor, `fix:` → patch, `feat!:`/`BREAKING CHANGE` → major).

- `main` → stable release: `vX.Y.Z` tag + GitHub Release.
- any other branch → pre-release: `vX.Y.Z-rc.N` tag + GitHub pre-release.

The job must check out the repository with `fetch-depth: 0` and have `contents: write`.

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `github_token` | ✅ | — | Token with `contents: write` (e.g. `${{ secrets.GITHUB_TOKEN }}`) |
| `config_file` | ❌ | bundled config | Base semantic-release config. A `.releaserc*` in the calling repo still takes precedence. It must keep an `@semantic-release/exec` step writing the next version to `.next-version` |

### Outputs

| Output | Description |
|---|---|
| `version` | Computed version, e.g. `v1.2.0` or `v1.2.0-rc.1` (empty when nothing was released) |
| `released` | `"true"` when a release was published, `"false"` otherwise |

---

## `build-and-push-docker-image`

Builds a Docker image and pushes it to a container registry: the data product's repository in the central Google Artifact Registry, or any username/password registry such as GHCR. A Docker image is optional for a data product: **without a Dockerfile this action does nothing** (set `skip_if_no_dockerfile: "false"` to fail instead).

Only the given `version` is pushed as a tag (no `latest`). Data product Artifact Registry repositories have **immutable tags**, so each tag can be pushed only once. Use the version computed by [`semantic-release`](#semantic-release) as the tag.

### Prerequisites

The workflow must authenticate as the data product's deployment service account, the only identity with write access to the repository. The `ARTIFACT_REGISTRY_REPOSITORY_URL` and `DEPLOYMENT_SERVICE_ACCOUNT_EMAIL` variables are created in the data product repository when the data product is created.

### Usage

```yaml
on:
  push:
    branches: ['**']
    paths: ['Dockerfile', 'src/**']   # avoids cutting a release for unrelated pushes

permissions:
  id-token: write
  contents: write

jobs:
  build-image:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - id: auth
        uses: aalloul/genesis-action/authenticate-with-gcp@v1
        with:
          workload_identity_provider: ${{ vars.WORKLOAD_IDENTITY_PROVIDER_NAME }}
          gcp_project: ${{ vars.PROJECT_ID }}
          service_account: ${{ vars.DEPLOYMENT_SERVICE_ACCOUNT_EMAIL }}
          token_format: access_token

      - id: release
        uses: aalloul/genesis-action/semantic-release@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}

      - if: ${{ steps.release.outputs.released == 'true' }}
        uses: aalloul/genesis-action/build-and-push-docker-image@v1
        with:
          repository_url: ${{ vars.ARTIFACT_REGISTRY_REPOSITORY_URL }}
          version: ${{ steps.release.outputs.version }}
          registry_password: ${{ steps.auth.outputs.access_token }}
```

For GHCR, pass the registry credentials explicitly (the job needs `packages: write`):

```yaml
      - uses: aalloul/genesis-action/build-and-push-docker-image@v1
        with:
          repository_url: ghcr.io/${{ github.repository_owner }}
          image_name: my-image
          version: ${{ steps.release.outputs.version }}
          registry_username: ${{ github.actor }}
          registry_password: ${{ secrets.GITHUB_TOKEN }}
```

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `repository_url` | ✅ | — | Artifact Registry repository URL, e.g. `europe-west1-docker.pkg.dev/my-project/my-repo` |
| `version` | ✅ | — | Image tag, typically the `semantic-release` `version` output |
| `registry_password` | ✅ | — | Registry password: the `access_token` output of `authenticate-with-gcp` for Artifact Registry, or `GITHUB_TOKEN` for GHCR |
| `registry_username` | ❌ | `oauth2accesstoken` | Registry username (`github.actor` for GHCR) |
| `image_name` | ❌ | GitHub repo name | Image name inside the repository |
| `context` | ❌ | `.` | Docker build context |
| `dockerfile` | ❌ | `Dockerfile` | Path to the Dockerfile |
| `build_args` | ❌ | `""` | Newline-separated `KEY=VALUE` build arguments |
| `skip_if_no_dockerfile` | ❌ | `true` | Exit successfully when the Dockerfile is missing |
| `push` | ❌ | `true` | Set to `false` to build without pushing |

### Outputs

| Output | Description |
|---|---|
| `image` | Full image reference including the tag (empty when nothing was built) |
| `digest` | Digest of the pushed image |
