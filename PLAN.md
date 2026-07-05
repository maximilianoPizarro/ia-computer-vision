# AI Computer Vision -- Validated Pattern Plan

**Maintainer**: Maximiliano Pizarro, Specialist Solution Architect (mapizarr@redhat.com)
**Status**: Implemented
**Base pattern**: [multicloud-gitops](https://github.com/validatedpatterns/multicloud-gitops)
**Source architecture**: [hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform)
**Target repo**: https://github.com/maximilianoPizarro/ia-computer-vision
**Tier**: Sandbox
**No PR to Validated Patterns yet** -- internal iteration only

---

## 1. Overview

Multi-cluster AI Computer Vision at the Edge pattern with hub-spoke GitOps, NeuroFace inference, Skupper mesh, and centralized observability. Installable via the Validated Patterns Operator on 3 clusters (hub + east spoke + west spoke).

## 2. Installation flow

On each cluster:
1. Install **Validated Patterns Operator** from OperatorHub
2. Create **Pattern CR** pointing to `ia-computer-vision` repo with `clusterGroupName` = `hub` | `east` | `west`
3. VP Operator bootstraps OpenShift GitOps (Red Hat, not community ArgoCD) and deploys `values-{clusterGroupName}.yaml`

```
Hub:   ./pattern.sh make install
East:  TARGET_CLUSTERGROUP=east ./pattern.sh make install
West:  TARGET_CLUSTERGROUP=west ./pattern.sh make install
```

## 3. Repository structure

```
ia-computer-vision/
├── Chart.yaml                  # Root umbrella (dep: clustergroup 0.9.*)
├── Makefile                    # VP standard targets
├── Makefile-common             # Shared VP make targets (load-secrets, upgrade)
├── pattern.sh                  # VP bootstrap script
├── pattern-metadata.yaml       # VP catalog metadata (name, tier, sizing, docs URLs)
├── values-global.yaml          # Pattern-wide globals
├── values-hub.yaml             # Hub clusterGroup definition
├── values-east.yaml            # East spoke clusterGroup definition
├── values-west.yaml            # West spoke clusterGroup definition
├── values-secret.yaml.template # Secrets template (v2.0 schema)
├── ansible.cfg                 # Ansible config for imperative jobs
├── .gitignore
├── .gitleaks.toml              # Secret scanning config
├── README.md                   # Business problem + solution + architecture diagram
├── SUPPORT.md                  # Sandbox tier, community best-effort
├── LICENSE                     # Apache-2.0
├── docs/                       # Hugo + AsciiDoctor documentation (GitHub Pages)
│   ├── config.yaml
│   ├── content/patterns/ia-computer-vision/
│   │   ├── _index.adoc
│   │   ├── getting-started.adoc
│   │   ├── cluster-sizing.adoc
│   │   ├── architecture.adoc
│   │   └── ideas-for-customization.adoc
│   ├── modules/ia-computer-vision/
│   │   ├── metadata-ia-computer-vision.adoc
│   │   ├── iacv-about.adoc
│   │   └── iacv-architecture.adoc
│   └── static/images/ia-computer-vision/
├── charts/
│   └── all/                    # 11 custom charts
│       ├── openshift-gitops/   # Hub: ArgoCD CR tuning (12Gi, health checks, ACM fix)
│       ├── neuroface-gateway/  # Hub: RHCL Gateway + HTTPRoute 50/50 + AuthPolicy
│       ├── gitlab-operator/    # Hub: GitLab instance + Runner
│       ├── developer-hub/      # Hub: RHDH with AI CV software template only
│       ├── openshift-ai-hub/   # Hub: DSC, KServe, workbenches, MaaS models
│       ├── spoke-neuroface/    # Spoke: NeuroFace full app stack
│       ├── spoke-neuroface-cv/ # Spoke: OVMS + YOLO CV inference
│       ├── spoke-interconnect/ # Spoke: Skupper VAN connector config
│       ├── servicemesh-config/ # Spoke: Istio/IstioCNI/ZTunnel ambient mode
│       ├── observability/      # Both: Grafana + OTel + dashboards + Kiali
│       └── acs-secured-cluster/# Spoke: SecuredCluster CR -> hub ACS Central
└── overrides/
    └── values-AWS.yaml
```

## 4. Hub cluster -- values-hub.yaml

### 4.1 Namespaces
`open-cluster-management`, `vault`, `external-secrets-operator`, `external-secrets`, `neuroface-gateway`, `stackrox`, `redhat-connectivity-link-operator`, `gitlab-system`, `rhdh-operator`, `developer-hub`, `keycloak-system`, `quay-enterprise`, `redhat-ods-operator`, `redhat-ods-applications`, `devspaces`

### 4.2 Subscriptions (operator installs via OLM)

| Operator | Subscription name | Channel | Purpose |
|----------|------------------|---------|---------|
| ACM | `advanced-cluster-management` | release-2.16 | Fleet management |
| ESO | `openshift-external-secrets-operator` | stable-v1 | External Secrets |
| ACS | `rhacs-operator` | stable | Security scanning |
| RHCL | `connectivity-link-operator` | stable | Gateway API + Kuadrant |
| Observability | `cluster-observability-operator` | stable | UIPlugin, Thanos |
| GitLab | `gitlab-operator-kubernetes` | stable | SCM for RHDH |
| RHDH | `rhdh` | fast | Developer Hub |
| RHBK | `rhbk-operator` | stable-v26.4 | OIDC SSO |
| Quay | `quay-operator` | stable | Image registry |
| Pipelines | `openshift-pipelines-operator-rh` | latest | Tekton CI/CD |
| RHOAI | `rhods-operator` | stable-3.4 | OpenShift AI 3 |
| DevSpaces | `devspaces` | stable | Developer workspaces |
| _RHTAS_ | _`rhtas-operator`_ | _stable_ | _Optional: artifact signing_ |
| _RHTPA_ | _`rhtpa-operator`_ | _stable_ | _Optional: SBOM analysis_ |
| _cert-manager_ | _`openshift-cert-manager-operator`_ | _stable-v1_ | _Optional: TLS for RHTAS_ |

### 4.3 Applications (ArgoCD apps)

| App | Source | Chart/Path | Notes |
|-----|--------|------------|-------|
| acm | VP chart | `chart: acm, 0.2.*` | MultiClusterHub CR |
| vault | VP chart | `chart: hashicorp-vault, 0.1.*` | Vault server |
| openshift-external-secrets | VP chart | `chart: openshift-external-secrets, 0.0.*` | ESO config |
| rhbk | VP chart | `chart: rhbk, 0.1.*` | Keycloak realm |
| quay | VP chart | `chart: quay, 0.1.*` | Quay registry |
| openshift-gitops | Local | `charts/all/openshift-gitops` | ArgoCD 12Gi tuning |
| neuroface-gateway | Local | `charts/all/neuroface-gateway` | RHCL 50/50 HTTPRoute |
| gitlab-operator | Local | `charts/all/gitlab-operator` | GitLab instance |
| developer-hub | Local | `charts/all/developer-hub` | AI CV template only |
| openshift-ai-hub | Local | `charts/all/openshift-ai-hub` | DSC, KServe, MaaS |

### 4.4 managedClusterGroups
- `east`: ACM label `clusterGroup=east`
- `west`: ACM label `clusterGroup=west`

## 5. Spoke clusters -- values-east.yaml / values-west.yaml

### 5.1 Subscriptions

| Operator | Channel | Purpose |
|----------|---------|---------|
| `amq-streams` | stable | Kafka messaging |
| `skupper-operator` | stable-2 | Cross-cluster connectivity |
| `rhacs-operator` | stable | ACS Secured Cluster |
| `servicemeshoperator3` | stable-3.2 | OSSM 3 ambient |
| `rhods-operator` | stable-3.4 | OpenShift AI |
| `grafana-operator` | v5 | Dashboards |
| `kiali-ossm` | stable | Mesh visualization |
| `opentelemetry-product` | stable | Distributed tracing |
| `cluster-observability-operator` | stable | UIPlugin, Thanos |
| `devspaces` | stable | Developer workspaces |
| `openshift-external-secrets-operator` | stable-v1 | ESO |
| `connectivity-link-operator` | stable | Gateway API |

### 5.2 Applications

| App | Source | Overrides |
|-----|--------|-----------|
| neuroface | External (`maximilianopizarro.github.io/neuroface/`) | Full stack overrides per spoke |
| spoke-neuroface | Local (platform wrappers) | `clusterName: east\|west` |
| spoke-neuroface-cv | Local | `clusterName: east\|west` |
| spoke-interconnect | Local | `clusterName: east\|west` |
| servicemesh-config | Local | ambient mode labels |
| observability | Local | Grafana + OTel + dashboards |
| acs-secured-cluster | Local | SecuredCluster CR |
| openshift-external-secrets | VP chart | ESO config |

## 6. OpenShift GitOps tuning

VP Operator (0.0.70+) installs OpenShift GitOps operator automatically. With `global.singleArgoCD: true`, single instance in `vp-gitops`.

**Hub** (via `openshift-gitops` chart):
- Controller: 6Gi request / 12Gi limit
- Repo server: 512Mi / 2Gi
- Redis: 256Mi / 512Mi
- Processors: operation=25, status=50
- `KUBECTL_PARALLELISM_LIMIT: "20"`
- Resource exclusions: `tekton.dev`, ACM internal CRDs
- Health checks: Subscription, Central (ACS), MultiClusterHub
- CronJob: ACM 2.16+ OpenAPI sync fix

**Spokes** (via values-east/west.yaml argoCD section):
- Default 4Gi + `GOMEMLIMIT=3600MiB` + `GOMAXPROCS=4`

## 7. Service Mesh ambient mode

Local chart `servicemesh-config/` (not VP `servicemesh` chart) for full control:
- `Istio` CR: `profile: ambient`, `PILOT_ENABLE_AMBIENT: "true"`
- `IstioCNI` CR: `profile: ambient`
- `ZTunnel` CR for L4 mTLS
- Namespace labels `istio.io/dataplane-mode: ambient` on `neuroface`, `neuroface-cv`
- `Telemetry` CR: Prometheus + OTel tracing

## 8. Secrets management

`values-secret.yaml.template` v2.0 schema, default `vault` backend:

| Secret | Fields | Generation |
|--------|--------|-----------|
| gitlab-credentials | root-password, runner-token | auto-generate |
| rhbk-credentials | admin-password | auto-generate |
| developer-hub-secrets | session-secret, gitlab-token | generate + manual |
| maas-credentials | api-key | manual (optional) |
| quay-credentials | dockerconfigjson | manual |

Supports `make secrets-backend-kubernetes` and `make secrets-backend-none`.

## 9. Cluster sizing

| Cluster | Control Plane | Workers | Instance Type |
|---------|--------------|---------|---------------|
| Hub | 3x m6a.2xlarge | 3x m6a.2xlarge | 8 vCPU / 32 GiB each |
| East | 3x m6a.2xlarge | 3x m6a.2xlarge | 8 vCPU / 32 GiB each |
| West | 3x m6a.2xlarge | 3x m6a.2xlarge | 8 vCPU / 32 GiB each |

GPU optional: `g4dn.xlarge` (T4) or `g5.2xlarge` (A10G) for spoke workers.

## 10. Sandbox tier compliance

| # | Requirement | Status |
|---|------------|--------|
| 1 | VP technical implementation | Standard structure with multiSourceConfig |
| 2 | Deployable on fresh OCP | `./pattern.sh make install` |
| 3 | README with business problem | AI CV at the edge + hub-spoke solution |
| 4 | Architecture drawing | Mermaid diagram hub/east/west |
| 5 | Technical review | Post-implementation |
| 6 | Architecture review | Post-implementation |
| 7 | Support policy | SUPPORT.md: sandbox, best-effort |

## 11. Documentation

Hugo + AsciiDoctor following:
- [VP Contributor's Guide](https://validatedpatterns.io/contribute/contribute-to-docs/)
- [Red Hat Supplementary Style Guide](https://redhat-documentation.github.io/supplementary-style-guide/)

Pages: `_index.adoc`, `getting-started.adoc`, `cluster-sizing.adoc`, `architecture.adoc`, `ideas-for-customization.adoc`

## 12. Implementation tasks

- [ ] Scaffold root VP files (Chart.yaml, values-global, pattern.sh, Makefile, etc.)
- [ ] Create values-hub.yaml (subscriptions + applications + managedClusterGroups)
- [ ] Create values-east.yaml (subscriptions + applications + overrides)
- [ ] Create values-west.yaml (clone of east with clusterName=west)
- [ ] Create 11 charts in charts/all/ (port from hybrid-mesh-platform)
- [ ] Create overrides/ directory
- [ ] Create README.md, SUPPORT.md, LICENSE
- [ ] Create docs/ folder with Hugo + AsciiDoctor structure
- [ ] Create Cursor skills for evolutivo

## 13. References

- https://validatedpatterns.io/patterns/multicloud-gitops/mcg-getting-started/
- https://validatedpatterns.io/contribute/sandbox/
- https://validatedpatterns.io/contribute/extending-a-pattern/
- https://validatedpatterns.io/learn/values-files/
- https://validatedpatterns.io/learn/clustergroup-in-values-files/
- https://validatedpatterns.io/learn/secrets-management-in-the-validated-patterns-framework/
- https://validatedpatterns.io/learn/infrastructure/
- https://validatedpatterns.io/contribute/contribute-to-docs/
- https://redhat-documentation.github.io/supplementary-style-guide/
- https://charts.validatedpatterns.io/
- https://github.com/maximilianoPizarro/hybrid-mesh-platform
