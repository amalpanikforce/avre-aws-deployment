# AVRE Client Deployment Guide

This document outlines the deployment workflow for AVRE application services using private GitHub Container Registry (GHCR), AWS Secrets Manager, and Terragrunt/OpenTofu.

---

## 1. Overview & Key Principles

- **Strict Config-Driven**: All required inputs MUST be defined in `config/<environment>.json`. If the file or any required input is missing, execution stops immediately ("Otherwise NO GO").
- **Strict Idempotency**: Running `deploy.sh` multiple times produces the exact same outcome without errors, duplicate resources, or breaking side-effects.
- **PAT Protection**: The GitHub Personal Access Token (PAT) is stored securely in AWS Secrets Manager and **never** printed, logged, committed, or passed in Terraform variables or state files.
- **Immutable Versioning**: Deployment tags (e.g., `1.0.2`) are dynamically resolved to their top-level multi-platform OCI index digest (`sha256:<digest>`).

---

## 2. Environment Configuration System (`config/*.json`)

### Required Config JSON Schema
Every client configuration (e.g., `config/sandbox.json`) contains **only 3 deploy-time fields**:

```json
{
  "aws_region": "ap-south-1",
  "ghcr_image": "ghcr.io/kcs-platform-engineering/avre",
  "version": "1.0.2"
}
```

**Why only 3 fields?** The remaining values are derived automatically — no duplication, no drift:

| Value | Source |
|---|---|
| `tg_dir` | Derived: `live/nonprod/<env>` (repo structure) |
| `secret_name` | Derived: `avre-<env>-ghcr-credentials` (naming convention) |
| `cluster_name` | Read from `terragrunt output` after apply |
| `service_name` | Read from `terragrunt output` after apply |

If any required field is missing from the JSON file, `deploy.sh` aborts with:
`ERROR: Missing required input(s) in 'config/sandbox.json': [field]. All inputs must be present in JSON file. Otherwise NO GO.`

---

## 3. Execution Syntax & Defaults

```bash
# 1. Zero Arguments (Defaults to sandbox using config/sandbox.json inputs):
./scripts/deploy.sh

# 2. Override version for sandbox:
./scripts/deploy.sh 1.0.3

# 3. Target specific client (uses config/<client>.json inputs):
./scripts/deploy.sh kforce

# 4. Target specific client with version override:
./scripts/deploy.sh kforce 1.0.3
```

---

## 4. Idempotency Guarantees

1. **Secret Creation**:
   - Reuses existing AWS Secrets Manager secret (`SECRET_NAME`).
   - Re-runs do not prompt for PAT or attempt duplicate creation.
2. **Digest Resolution**:
   - OCI index digest resolution (`sha256:...`) is deterministic for a given tag.
3. **Terragrunt Apply**:
   - Re-running with the same image digest results in `No changes. Infrastructure is up-to-date.`.
4. **ECS Service Stability**:
   - `aws ecs wait services-stable` verifies the ECS service state and exits cleanly when stable.
