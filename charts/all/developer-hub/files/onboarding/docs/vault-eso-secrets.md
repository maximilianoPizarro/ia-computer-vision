# Vault and External Secrets Operator

The hub stores sensitive values in **HashiCorp Vault**. The **External Secrets Operator (ESO)** projects them into native OpenShift `Secret` objects that pods and operators consume. **No secret values are committed to Git.**

![Scaffolding and Vault/ESO operator flows](images/scaffolding-vault-eso-flow.png)

## What it is

| Layer | Responsibility |
|-------|----------------|
| **values-secret.yaml** | You define which secrets exist and which fields are auto-generated vs manual (file stays outside Git). |
| **Validated Patterns Operator** | Loads secret fields into Vault during hub install (`./pattern.sh make load-secrets`). |
| **Vault** | System of record — paths like `secret/hub/developer-hub-secrets`, `secret/hub/rhbk-credentials`. |
| **ClusterSecretStore** | ESO configuration pointing at Vault (`vault-backend`). |
| **ExternalSecret** | Declarative mapping (in Git) from Vault path + property → Kubernetes Secret name + key. |
| **Kubernetes Secret** | Native OpenShift object mounted by Deployments, StatefulSets, and operators. |

## How ESO connects to OpenShift secrets

```
values-secret.yaml  →  VP Operator  →  Vault KV
                                          ↓
ExternalSecret (Git)  →  ESO controller  →  Secret (namespace)
                                          ↓
                              Pod envFrom / secretRef / volumeMount
```

1. **Git** contains only the `ExternalSecret` manifest — for example which Vault key and property to read.
2. **ESO** polls Vault on `refreshInterval` (typically 1h) and creates or updates the target `Secret`.
3. **Workloads** reference the Kubernetes `Secret` by name — they never call Vault directly.
4. If Vault is sealed, empty, or missing a key, ESO reports `SecretSyncedError` and dependent pods stay pending.

## Pattern secrets (hub)

| Vault path | Keys | Consumed by |
|------------|------|-------------|
| `developer-hub-secrets` | `oidc-client-secret`, `session-secret`, `gitlab-token` | RHDH OIDC, scaffolder, ApplicationSet GitLab token |
| `rhbk-credentials` | `admin-password`, `db-password` | RHBK, PostgreSQL |
| `gitlab-credentials` | `root-password`, `runner-token` | GitLab instance |
| `spoke-credentials` | `east-token`, `west-token`, … | ACM auto-import (vault mode) |
| `maas-credentials` | `api-key` | OpenShift AI MaaS (optional) |

Define them in `values-secret.yaml.template` at the repository root. Copy to `~/values-secret-ia-computer-vision.yaml` before hub install.

## Example: GitLab token for scaffolder

**User input** (after GitLab deploys):

```bash
oc exec vault-0 -n vault -- vault kv patch secret/hub/developer-hub-secrets \
  gitlab-token="<PAT with api scope>"
```

**ExternalSecret** (in Git — simplified):

```yaml
spec:
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: developer-hub-oidc-auth
  data:
    - secretKey: gitlab_token
      remoteRef:
        key: secret/data/hub/developer-hub-secrets
        property: gitlab-token
```

**Expected result:**

- Kubernetes Secret `developer-hub-oidc-auth` in `developer-hub` with key `GITLAB_TOKEN`
- Kubernetes Secret `gitlab-scm-token` in `vp-gitops` for ApplicationSet SCM provider
- Software template publish step and GitLab repo discovery succeed

## Example: RHBK database password

Vault auto-generates `db-password` when `onMissingValue: generate` is set. ESO syncs it to PostgreSQL and RHBK operands. If `./pattern.sh make load-secrets` was never run, ExternalSecrets show `Secret does not exist` and RHBK stays `Progressing`.

## Verify ESO health

```bash
oc get externalsecret -A | grep -v SecretSynced
oc get clustersecretstore vault-backend
oc get secret developer-hub-oidc-auth -n developer-hub -o jsonpath='{.data}' | wc -c
```

## Spoke credential modes

| Mode | Description |
|------|-------------|
| `vault` | Tokens in Vault; ESO or sync job injects for ACM import. |
| `inline` | Pattern CR `extraParameters` pass tokens (sandbox). |
| `secret` | Pre-created Kubernetes Secret. |

## Related

- [AI Computer Vision scaffolding](ai-computer-vision-scaffolding.md)
- [Validated Patterns secrets management](https://validatedpatterns.io/learn/secrets-management-in-the-validated-patterns-framework/)
- Pattern docs: [Scaffolding and secrets](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/scaffolding-and-secrets/)
