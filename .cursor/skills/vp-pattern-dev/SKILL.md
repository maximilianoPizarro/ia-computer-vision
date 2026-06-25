---
name: vp-pattern-dev
description: >-
  Validated Patterns development guidelines for ia-computer-vision. Use when
  creating, extending, or modifying VP pattern files (values-*.yaml, Chart.yaml,
  subscriptions, applications, pattern-metadata.yaml, pattern.sh, Makefile).
  Also use when adding operators, charts, or namespaces to the pattern.
---

# Validated Patterns Development -- ia-computer-vision

## Pattern identity

- **Name**: ia-computer-vision
- **Tier**: Sandbox
- **Maintainer**: Maximiliano Pizarro, Specialist Solution Architect (mapizarr@redhat.com)
- **Repo**: https://github.com/maximilianoPizarro/ia-computer-vision
- **Base**: multicloud-gitops (VP standard)
- **Source architecture**: hybrid-mesh-platform

## Core VP structure rules

1. **Root files**: `values-global.yaml`, `values-{clusterGroupName}.yaml`, `Chart.yaml` (dep on `clustergroup` from `charts.validatedpatterns.io`), `pattern.sh`, `Makefile`
2. **Cluster roles**: `hub`, `east`, `west` -- each maps to `values-hub.yaml`, `values-east.yaml`, `values-west.yaml`
3. **`global.singleArgoCD: true`** -- single ArgoCD instance managed by VP Operator in `vp-gitops`
4. **`multiSourceConfig.enabled: true`** with `clusterGroupChartVersion: "0.9.*"`
5. **VP Operator handles OpenShift GitOps** -- do NOT add `openshift-gitops-operator` subscription

## Adding an operator (4-step process)

Per https://validatedpatterns.io/contribute/extending-a-pattern/:

1. **Add namespace** in `clusterGroup.namespaces` of the target `values-*.yaml`
2. **Add subscription** in `clusterGroup.subscriptions` (OLM installs the operator)
3. **Add ArgoCD application** in `clusterGroup.applications` (either `chart:` for VP published charts or `path:` for local charts)
4. **Add Helm chart** in `charts/all/{name}/` only if custom CRs are needed beyond the operator install

Subscription format:
```yaml
subscriptions:
  my-operator:
    name: my-operator
    namespace: my-namespace        # default: openshift-operators
    channel: stable
    source: redhat-operators       # default
```

Application format (VP chart):
```yaml
applications:
  my-app:
    name: my-app
    namespace: my-namespace
    argoProject: hub
    chart: my-chart                # from charts.validatedpatterns.io
    chartVersion: 0.1.*
```

Application format (local chart):
```yaml
applications:
  my-app:
    name: my-app
    namespace: my-namespace
    argoProject: hub
    path: charts/all/my-app
    overrides:
      - name: clusterName
        value: east
```

## VP published charts (use instead of local charts)

Available at https://charts.validatedpatterns.io/ -- reference by `chart:` + `chartVersion:`:

| Chart | Version | Purpose |
|-------|---------|---------|
| `acm` | 0.2.* | ACM MultiClusterHub config |
| `hashicorp-vault` | 0.1.* | Vault server |
| `openshift-external-secrets` | 0.0.* | ESO config |
| `rhbk` | 0.1.* | Red Hat Build of Keycloak |
| `servicemesh` | 0.1.* | OSSM 3.0 (but we use local for ambient control) |
| `llm-inference-service` | 0.3.* | KServe inference |
| `letsencrypt` | 0.1.* | TLS certificates |

## Local chart structure

Each chart in `charts/all/{name}/` must have:
```
charts/all/{name}/
├── Chart.yaml      # apiVersion: v2, type: application
├── values.yaml     # defaults
└── templates/
    └── *.yaml      # Kubernetes CRs
```

Chart.yaml template:
```yaml
apiVersion: v2
name: {name}
description: {description}
type: application
version: 0.1.0
maintainers:
  - name: Maximiliano Pizarro
    email: mapizarr@redhat.com
```

Use `argocd.argoproj.io/sync-wave` annotations for ordering. Use `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` for CRDs that may not exist yet.

## Secrets (values-secret.yaml.template)

- Schema version 2.0
- Default backend: vault
- Use `onMissingValue: generate` with `vaultPolicy: validatedPatternDefaultPolicy` for auto-generated passwords
- Never commit actual secret values to Git
- Secrets loader searches: `~/.config/validated-patterns/values-secret-ia-computer-vision.yaml` first

## Sandbox tier requirements

1. VP-conformant structure (multiSourceConfig, clustergroup dep)
2. Deployable on fresh OCP without modification
3. README with business problem + solution
4. Architecture drawing
5. Technical review (post-implementation)
6. Architecture review (post-implementation)
7. SUPPORT.md documenting support policy

## Current chart inventory

### Hub charts (values-hub.yaml)
| Chart | Type | Wave | ArgoProject |
|-------|------|------|-------------|
| `openshift-gitops` | local | 0 | platform |
| `platform-users` | local | 0 | platform |
| `observability` | local | 1 | observability |
| `acm` | VP chart | 1 | hub |
| `vault` | VP chart | 2 | external-secrets |
| `openshift-external-secrets` | VP chart | 2 | external-secrets |
| `rhbk` | VP chart | 2 | workshop |
| `gitlab-operator` | local | 3 | workshop |
| `developer-hub` | local | 4 | workshop |
| `servicemesh-config` | VP chart (`servicemesh:0.1.*`) | 5 | mesh (required for neuroface-gateway Istio) |
| `openshift-ai-hub` | local | 5 | ai |
| `mailpit` | local | 5 | workshop (Mailpit UI + PPE Kafka consumer) |
| `hub-interconnect` | local | 5 | mesh (Skupper VAN + Kafka listener) |
| `neuroface-gateway` | local | 6 | mesh |
| `acm-hub-spoke` | local | 6 | hub |
| `acs-init-bundle-sync` | local | 7 | security |
| `devspaces` | local | 7 | workshop |
| `console-links` | local | 10 | workshop |

### Spoke charts (values-east.yaml / values-west.yaml)
| Chart | Type | Wave | ArgoProject |
|-------|------|------|-------------|
| `platform-users` | local | 0 | platform (creates `acm-import` SA with cluster-admin) |
| `servicemesh-config` | VP chart (`servicemesh:0.1.*`) | 1 | mesh |
| `openshift-external-secrets` | VP chart | 2 | external-secrets |
| `observability` | local | 2 | observability (also deploys spoke DSC for KServe CRDs) |
| `acs-secured-cluster` | local | 3 | security |
| `spoke-interconnect` | local | 4 | mesh |
| `spoke-neuroface` | local | 5 | ai (includes ApplicationSet for user NeuroFace repos) |
| `spoke-neuroface-cv` | local | 6 | ai |
| `devspaces` | local | 7 | workshop |
| `console-links` | local | 10 | workshop |

## Known limitations (sandbox)

- **Image builds**: Use OpenShift internal registry for scaffolded NeuroFace Tekton pipelines (Quay removed from pattern).
- **Per-user RHBK**: Software template deploys RHBK biometric + OIDC AuthPolicy per user on spokes via ApplicationSet.
- **Hub sizing**: `m6a.2xlarge` workers saturate at 98-99% CPU requests. Use `m6a.4xlarge` for production or remove master taints for sandbox.
- **Developer Hub plugins**: OCM, Tekton, Topology, Kafka, Quay community plugins do not ship in RHDH 1.10 image. Must be `disabled: true` in `dynamic-plugins-rhdh` ConfigMap.
- **Vault secrets**: If installed via OCP console Pattern CR (not CLI), secrets are not auto-loaded. Populate Vault manually after Vault initializes (wave 2). See README "Option B — Console install".
- **RHBK**: The `rhbk-credentials` secret must include both `admin-password` and `db-password` fields.
- **Skupper console link**: Points to hub but Skupper only runs on spokes. The hub console link will always show 503.

## Lessons learned from installation (Jun 2026)

### OperatorGroup install modes
Operators like RHCL and Cluster Observability Operator do NOT support `OwnNamespace` install mode. Spoke namespaces for these operators MUST declare `operatorGroup: true` + `targetNamespaces: []` (AllNamespaces mode). Without this, CSVs fail with `OwnNamespace InstallModeType not supported`.

### ACM auto-import RBAC
The `acm-spoke-auto-import` CronJob ServiceAccount requires these permissions beyond basic `managedclusters` CRUD:
- `cluster.open-cluster-management.io/managedclustersets/join` (create) — ACM auto-adds clusters to the `default` clusterset
- `cluster.open-cluster-management.io/managedclusters/accept` (update) — required to set `hubAcceptsClient: true`
- `register.open-cluster-management.io/managedclusters/accept` (update) — alternative API group for the same
- Namespace `create` verb — to wait for ACM to create the spoke namespace

### Spoke import tokens
The default ServiceAccount `kube-system:default` does NOT have `cluster-admin` permissions. The pattern auto-creates `kube-system:acm-import` SA with `cluster-admin` via `platform-users` chart (wave 0). Users only need to generate the token: `oc create token -n kube-system acm-import --duration=87600h`.

### KServe CRDs on spokes
Spokes subscribe to RHOAI but the `InferenceService` and `ServingRuntime` CRDs are only installed when a `DataScienceCluster` CR exists with `kserve.managementState: Managed`. The pattern places a minimal DSC (KServe-only, everything else Removed) in the `observability` chart (wave 2) — NOT in `spoke-neuroface-cv` (wave 6) because that creates a deadlock (chart needs CRDs that only exist after the chart syncs).

### Service Mesh on hub
The hub MUST have `servicemeshoperator3` subscription and a `servicemesh-config` application (VP `servicemesh` chart with `profile: ambient`) for the NeuroFace Gateway (`gatewayClassName: istio`). Without it, the Gateway shows `Waiting for controller` / `PROGRAMMED: Unknown`.

### Developer Hub YAML config
The `catalog.providers.gitlab` config must NOT have duplicate `schedule:` keys. RHDH YAML parser is strict and crashes on duplicate map keys (`YAMLParseError: Map keys must be unique`).

### Developer Hub missing namespaces
RHDH templates reference namespaces `gitlab`, `keycloak`, `east`, `west` for RBAC/spoke-token-sync. These must exist before the developer-hub app syncs. If they don't exist, ArgoCD retries until they are created.

### Console install (Pattern CR) secrets
When installing via the OCP console (Pattern CR), `make load-secrets` is NOT executed. Vault initializes empty. You must load secrets manually:
```bash
oc exec vault-0 -n vault -- vault kv put secret/hub/gitlab-credentials root-password="$(openssl rand -base64 16)" runner-token="$(openssl rand -base64 16)"
oc exec vault-0 -n vault -- vault kv put secret/hub/rhbk-credentials admin-password="$(openssl rand -base64 16)" db-password="$(openssl rand -base64 16)"
oc exec vault-0 -n vault -- vault kv put secret/hub/developer-hub-secrets session-secret="$(openssl rand -base64 32)" gitlab-token="placeholder"
oc exec vault-0 -n vault -- vault kv put secret/hub/maas-credentials api-key="placeholder"
oc exec vault-0 -n vault -- vault kv put secret/hub/developer-hub-secrets session-secret="$(openssl rand -base64 32)" gitlab-token="<GITLAB_PAT>"
```
After loading, force ESO refresh: `oc annotate externalsecret -n keycloak-system --all force-sync=$(date +%s) --overwrite`

## Key constraints

- Developer Hub: only `ai-computer-vision` software template
- TSSC (RHTAS, RHTPA): optional, commented out in values-hub.yaml
- Service Mesh: VP `servicemesh` chart with `profile: ambient` on hub and spokes
- ArgoCD: hub needs 12Gi controller memory via `openshift-gitops` chart
- Community plugins: disable in `configmap-dynamic-plugins-rhdh.yaml` any `backstage-community-plugin-*` not in the RHDH image
- API catalog: `workshop-kuadrant-apis.yaml` and `public-apis.yaml` use `__SPEC__` placeholders injected by `catalog-kuadrant-apis.yaml` and `catalog-public-apis.yaml` templates

## Reference plan

See [PLAN.md](../../PLAN.md) for the full implementation plan.
