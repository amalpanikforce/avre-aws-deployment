# AVRE AWS Deployment

This repository is the deployment-only counterpart to the AVRE AWS infrastructure repo. It is intentionally scoped to ECS deployments and does not include the shared `core` stack or other infrastructure layers.

## Design

- Deployment-first structure modeled after the Azure deployment pattern
- Terragrunt-based environment entrypoints under `live/`
- ECS Fargate task/service deployment via a focused Terraform module
- No shared `core` ECR stack or non-ECS deployment modules

## Repository layout

```text
avre-aws-deployment/
├── Makefile
├── README.md
├── live/
│   ├── root.hcl
│   └── nonprod/
│       └── sandbox/
│           ├── env.hcl
│           └── terragrunt.hcl
└── modules/
    └── ecs-deployment/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Typical usage

```bash
make plan STACK=sandbox
make apply STACK=sandbox
make output STACK=sandbox
```

## Required values before deploy

Update `live/nonprod/sandbox/env.hcl` with your:

- AWS region
- subnet IDs
- security group IDs
- container image
- application environment variables
- optional secrets

This repo expects the network and security context to already exist outside this deployment layer.
