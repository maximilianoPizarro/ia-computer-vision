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
| `quay` | 0.1.* | Quay Registry |
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
| `quay` | VP chart | 2 | workshop (requires ODF) |
| `gitlab-operator` | local | 3 | workshop |
| `developer-hub` | local | 4 | workshop |
| `openshift-ai-hub` | local | 5 | ai |
| `showroom` | local | 5 | workshop |
| `neuroface-gateway` | local | 6 | mesh |
| `acm-hub-spoke` | local | 6 | hub |
| `acs-init-bundle-sync` | local | 7 | security |
| `devspaces` | local | 7 | workshop |
| `console-links` | local | 10 | workshop |

### Spoke charts (values-east.yaml / values-west.yaml)
| Chart | Type | Wave | ArgoProject |
|-------|------|------|-------------|
| `openshift-gitops` | local | 0 | platform |
| `platform-users` | local | 0 | platform |
| `openshift-external-secrets` | VP chart | 1 | external-secrets |
| `servicemesh-config` | local | 1 | mesh |
| `observability` | local | 2 | observability |
| `acs-secured-cluster` | local | 3 | security |
| `spoke-neuroface` | local | 5 | ai |
| `spoke-neuroface-cv` | local | 6 | ai |
| `spoke-interconnect` | local | 7 | mesh |
| `devspaces` | local | 7 | workshop |
| `console-links` | local | 10 | workshop |

## Known limitations (sandbox)

- **Quay** requires ODF (ObjectBucketClaim). Without ODF, the app shows `Missing`. Disable or install ODF.
- **Hub sizing**: `m6a.2xlarge` workers saturate at 98-99% CPU requests. Use `m6a.4xlarge` for production or remove master taints for sandbox.
- **Developer Hub plugins**: OCM, Tekton, Topology, Kafka, Quay community plugins do not ship in RHDH 1.10 image. Must be `disabled: true` in `dynamic-plugins-rhdh` ConfigMap.
- **Vault secrets**: If installed via OCP console Pattern CR (not CLI), secrets are not auto-loaded. Run `./pattern.sh make load-secrets` or populate Vault manually.
- **RHBK**: The `rhbk-credentials` secret must include both `admin-password` and `db-password` fields.
- **Spoke connectivity**: Spokes require Skupper and Service Mesh operators (subscriptions in `values-east.yaml`). The hub does NOT subscribe to these operators (Skupper runs on spokes only; Service Mesh on hub is installed via RHOAI operator).

## Key constraints

- Port charts from hybrid-mesh-platform, simplifying where possible
- Developer Hub: only `ai-computer-vision` software template (not all 8 from hybrid-mesh-platform)
- TSSC (RHTAS, RHTPA): optional, commented out in values-hub.yaml
- Service Mesh: local chart for ambient mode (not VP `servicemesh` chart)
- ArgoCD: hub needs 12Gi controller memory via `openshift-gitops` chart
- Community plugins: disable in `configmap-dynamic-plugins-rhdh.yaml` any `backstage-community-plugin-*` from `./dynamic-plugins/dist/` not present in the RHDH image

## Reference plan

See [PLAN.md](../../PLAN.md) for the full implementation plan.
