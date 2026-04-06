# Genesis action package

This repository provides reusable GitHub actions to enable other organizations deploy their data infrastructure using the Genesis framework.

The Genesis framework is a set of tools and best practices for building data infrastructure. This framework currently only supports 
GCP and its suit of services.
What it does, in a nutshell:
basic infra:
- Create a GCP project under a specific folder in the organization
- Create a VPC and a VPC-SC
- Create a Cloud Composer environment

data product:
- Create a GCP project under a specific folder in the organization
- attach this project to the VPC and VPC-SC created by the basic infra
- create a github repo in the organization's environment
- create a ci/cd pipeline that will allow people to create resources in the relevant gcp project

The resulting infrastructure created by the actions in this repo will be hosted on each customer's cloud (GCP for now, others later). 
This means that the actions in this repo will need to authenticate with the customer's cloud to be able to create the infrastructure. 

## Actions
- create-basic-infra: this action calls pulls a Docker container from the Genesis infra repository and runs the `create-basic-infra` command.
This command creates a bunch of Terraform files correctly configured for the calling organization. The action then runs Terraform to create
the infrastructure in GCP. 

- authenticate-with-gcp: this action holds the logic to authenticate with GCP using WIF. It is expected to be reused by other 
actions in this repo (for example, the `create-basic-infra` action) to authenticate with GCP.

- create-data-product: [not yet created] this action will call a Docker container from the Genesis infra repository and run the `create-data-product` command. 
This command creates a bunch of Terraform files correctly configured for the data product being created. The action then runs Terraform 
to create the infrastructure in GCP.


## Ways of working:
- We want to use WIF to authenticate the action with GCP. 
- The github workflow defined in `.github/workflows/publish_actions.yml` must validate the actions defined in this repo before running semantic-release.
- the actions in this repo are public and can be re-used by anyone. It is therefore important that they be documented and flexible. We don't know, for example,
the service account name or the WIF pool of the calling repository, so these should be parameters of the actions, if required.
