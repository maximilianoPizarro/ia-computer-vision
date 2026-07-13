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
| `openshift-gitops` | local | 0 | platform (only sets `ArgoCD/vp-gitops` `spec.localUsers` via `argocdLocalUser.enabled=true` — deliberately does NOT set `spec.rbac`/`controller`/`server`/etc.; see the `patterns-operator` root-cause entry below for why) |
| `openshift-lightspeed` | local | — | platform (OpenShift Lightspeed operator + `OLSConfig`; LLM provider = legacy `ai-gateway`/Kuadrant, MCP server = `argocd-mcp`; see the Lightspeed/Kuadrant WASM entry below for a known, unresolved LLM-connectivity issue) |
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
| `models-as-a-service` | local | 6 | ai (native RHOAI 3.4 MaaS: Tenant, Gateway, Gen AI Studio) |
| `argocd-mcp` | local | 3 | hub (mcp-for-argocd, hub-only) |
| `mailpit` | local | 5 | workshop (Mailpit UI + PPE Kafka consumer) |
| `rhbk-iam` | local | 2 | workshop (per-user realms: neuroface/maas/cv, `backstage-provisioner` client) |
| `hub-interconnect` | local | 5 | mesh (Skupper VAN + Kafka listener) |
| `skupper-network-observer` | local | 5 | mesh |
| `mailpit` | local | 5 | workshop (Mailpit UI + PPE Kafka consumer) |
| `neuroface-gateway` | local | 6 | mesh |
| `workshop-kuadrant-apis` | local | 6 | workshop (AI Gateway, workshop API products; owns the cluster-wide `Kuadrant`/`Authorino`/`Limitador` singleton — see pitfall below) |
| `acm-hub-spoke` | local | 6 | hub |
| `acs-init-bundle-sync` | local | 7 | security (**disabled by default** — commented out to save resources) |
| `devspaces` | local | 7 | workshop |
| `workshop-registration` | local | 5 | workshop |
| `console-links` | local | 10 | workshop |

Verify the live app list with `oc get application -n vp-gitops` — it drifts from this table faster than the table gets updated; treat this as a starting point, not a source of truth.

### Spoke charts (values-east.yaml / values-west.yaml)
| Chart | Type | Wave | ArgoProject |
|-------|------|------|-------------|
| `platform-users` | local | 0 | platform (creates `acm-import` SA with cluster-admin) |
| `argocd-local-users` | local | 0 | platform (sole owner of `spec.rbac`/`localUsers` on spoke `vp-gitops` — **not deployed on hub**, see openshift-gitops singleton note; verify ACM mustonlyhave on spokes) |
| `argocd-mcp-spoke-export` | local | 1 | platform (exports ai-agent token to ConfigMap for hub sync) |
| `servicemesh-config` | VP chart (`servicemesh:0.1.*`) | 1 | mesh |
| `openshift-external-secrets` | VP chart | 2 | external-secrets |
| `observability` | local | 2 | observability (also deploys spoke DSC for KServe CRDs) |
| `acs-secured-cluster` | local | 3 | security (**disabled by default** — commented out to save resources) |
| `spoke-interconnect` | local | 4 | mesh |
| `spoke-neuroface` | local | 5 | ai (includes ApplicationSet for user NeuroFace repos) |
| `spoke-neuroface-cv` | local | 6 | ai |
| `kafka-console` | local | — | ai (Kafka UI for PPE detection events) |
| `skupper-network-observer` | local | — | mesh |
| `devspaces` | local | 7 | workshop |
| `console-links` | local | 10 | workshop |

## Hub-only + GPU + pre-installed-operators overlay stack

Five OPT-IN overlay files at the repo root, composable via the Pattern CR's `extraValueFiles` on top of the default `values-hub.yaml`. None of them are loaded unless explicitly listed — the tagged/default install path is completely unaffected.

**Authoritative Pattern CR decision table:** `docs/content/patterns/ia-computer-vision/pattern-cr-guide.adoc` and ready-to-apply YAML in `examples/pattern-cr/`.

| Scenario | extraValueFiles | Example file |
|----------|-----------------|--------------|
| **A — Hub-only CPU (default)** | `values-hub-only.yaml` | `examples/pattern-cr/hub-only-cpu.yaml` |
| B — Hub + spokes CPU | *(none on hub)* | `examples/pattern-cr/hub-spoke-cpu.yaml` |
| C — Hub-only GPU multi-node | `values-hub-gpu.yaml`, `values-hub-only.yaml` | `examples/pattern-cr/hub-only-gpu-multi-node.yaml` |
| D — Hub-only GPU single-node + pre-installed ops | gpu → single-node → rhpds → hub-only | `examples/pattern-cr/hub-only-gpu-single-node-preinstalled.yaml` |
| E — Spoke | *(none)* | `examples/pattern-cr/spoke.yaml` |

Public docs for pre-installed-operator sandboxes (no vendor name in prose): `ideas-for-customization.adoc`, "Configuring GPU inference on a cluster with pre-installed operators".

| File | Purpose | Depends on |
|------|---------|------------|
| `values-hub-gpu.yaml` | GPU-backed vLLM model serving on the hub (`openshift-ai-hub` `gpu.enabled`, `charts/all/openshift-ai-hub/templates/gpu-vllm-models.yaml`); installs its own NFD + NVIDIA GPU Operator subscriptions | none — works standalone on a from-scratch multi-node hub |
| `values-hub-single-node.yaml` | Scales `userCount`/replica counts to 5 across ~11 applications so the stack fits a single-node kubelet `maxPods` ceiling | composes with `values-hub-gpu.yaml` |
| `values-hub-rhpds.yaml` | Adapts to a cluster where NFD, GPU Operator, Service Mesh, OpenShift AI, and Connectivity Link are **already installed by someone else**: skips creating a second `OperatorGroup` in those namespaces, pins ZTunnel's `spec.version` to match the pre-installed Istio, points `models-as-a-service` at the pre-installed Connectivity Link's `kuadrant-system` namespace, enables `autoApproveManualInstallPlans`, and sets a `ssoHostPrefix: rhdh-sso` override (six charts, see below) when a pre-existing SSO/Keycloak instance already claims the default `sso.<domain>` hostname | loads after `values-hub-single-node.yaml` — see the override-wholesale-replace warning below |
| `values-hub-only.yaml` | Hub-only install with no east/west spokes: disables Skupper/`hub-interconnect`/`acm-hub-spoke`, deploys the upstream `neuroface` chart + local Kafka (Strimzi) on the hub, routes `neuroface(-cv).apps.*` via `neuroface-gateway` `hubLocal` mode | optional, loads last |
| `values-hub-gpu-minimal.yaml` | Fallback for sandboxes where `maxPods` cannot be raised: disables the entire workshop/dev platform (GitLab, Developer Hub, DevSpaces, RHBK, Lightspeed) and keeps only Vault/ESO + OpenShift AI + vLLM `InferenceService`s | only when `values-hub-single-node.yaml` is not enough; loads after all four above |

Documented Pattern CR order for **Scenario D only**: `values-hub-gpu.yaml` → `values-hub-single-node.yaml` → `values-hub-rhpds.yaml` → `values-hub-only.yaml` (→ `values-hub-gpu-minimal.yaml` if needed). **Scenario A (most common)** uses only `values-hub-only.yaml`.

### `ssoHostPrefix` — six charts must move together
`developer-hub`, `rhbk-iam`, `neuroface-gateway`, `workshop-registration`, `devspaces`, `console-links` all read a chart-local `ssoHostPrefix` (default `"sso"`). If a pre-existing SSO instance already claims `sso.<domain>`, override all six to the same alternate value — a partial update leaves whichever chart(s) you missed pointing at the dead hostname. `values-hub-rhpds.yaml` sets all six to `rhdh-sso`.

### Single-node maxPods ceiling
See `docs/content/patterns/ia-computer-vision/cluster-sizing.adoc`, "Single-node sandboxes" — a control-plane-and-worker-combined node running a pre-provisioned RHACM/Pipelines/RHOAI/GPU-Operator baseline consumes ~110-130 of the kubelet's default 250 `maxPods` before this pattern installs anything. Prefer raising `maxPods` to 500 via `KubeletConfig` (one-time reboot) over `values-hub-gpu-minimal.yaml`, which strips real functionality instead.

## Known limitations (sandbox)

- **Image builds**: Use OpenShift internal registry for scaffolded NeuroFace Tekton pipelines (Quay removed from pattern).
- **Per-user RHBK**: Software template deploys RHBK biometric + OIDC AuthPolicy per user on spokes via ApplicationSet.
- **Hub sizing**: `m6a.2xlarge` workers saturate at 98-99% CPU requests. Use `m6a.4xlarge` for production or remove master taints for sandbox.
- **Developer Hub plugins**: OCM, Tekton, Topology, Kafka, Quay community plugins do not ship in RHDH 1.10 image. Must be `disabled: true` in `dynamic-plugins-rhdh` ConfigMap.
- **Vault secrets**: If installed via OCP console Pattern CR (not CLI), secrets are not auto-loaded. Populate Vault manually after Vault initializes (wave 2). See README "Option B — Console install".
- **RHBK**: The `rhbk-credentials` secret must include both `admin-password` and `db-password` fields.
- **Skupper console link**: Points to hub but Skupper only runs on spokes. The hub console link will always show 503.

## Lessons learned from installation and software template launch (Jun 2026)

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
```
After loading, force ESO refresh: `oc annotate externalsecret -n keycloak-system --all force-sync=$(date +%s) --overwrite`
Note: `gitlab-token` can stay as `placeholder` — the `gitlab-token-setup` PostSync job (developer-hub chart) auto-creates a PAT and patches both the K8s Secret and Vault.

### GitLab external URL (`gitlab-gitlab.apps` vs `gitlab.apps`)
The GitLab operator creates an Ingress with hostname `gitlab-gitlab.apps.<domain>` (from `hostSuffix: gitlab`). OpenShift translates this into a Route, but WITHOUT TLS termination by default. HTTPS git push to `gitlab-gitlab.apps` returns **503** (OpenShift "Application not available" page).
**Fix**: Set `global.hosts.gitlab.name` in the GitLab CR to `gitlab.apps.<domain>` (via Helm helper `gitlab-operator.host`). This overrides the auto-generated hostname so clone URLs (http_url_to_repo) use the working `gitlab.apps` route. Also add `route.openshift.io/termination: edge` in ingress annotations. The custom `route-gitlab-apps.yaml` uses the same helper and has TLS edge termination.

### RHDH scaffolder `publish:gitlab` input schema
The RHDH dynamic plugin `backstage-plugin-scaffolder-backend-module-gitlab-dynamic` does NOT accept `description` or `repoVisibility` as top-level inputs. These must go under `settings`:
```yaml
action: publish:gitlab
input:
  repoUrl: "gitlab.apps.{{ domain }}?owner=group&repo=name"
  defaultBranch: main
  settings:
    description: "Project description"
    visibility: public
```
Using top-level `description` causes `InputError: instance is not allowed to have the additional property "description"`.

### RHDH GitLab token lifecycle (stale pod token)
ESO syncs the GitLab PAT from Vault into the `developer-hub-oidc-auth` Secret, but the RHDH pod only reads `GITLAB_TOKEN` at startup (`envFrom`). If the Secret updates after the pod starts, the pod keeps the old (possibly placeholder) value until restarted. The `gitlab-token-setup` PostSync job now:
1. Checks if the Secret token is valid (GitLab API 200)
2. Compares the Secret token with the running pod's `GITLAB_TOKEN` env var
3. If they differ, restarts the `backstage-developer-hub` deployment
4. If no valid token exists, creates a new PAT via `gitlab-rails runner`
5. Patches both the K8s Secret AND Vault (`secret/hub/developer-hub-secrets gitlab-token`)
6. Restarts RHDH to load the new token

This eliminates the manual step of patching Vault after GitLab deploys.

### ApplicationSet SSH_AUTH_SOCK error
When `user-neuroface-apps` ApplicationSet finds repos via scmProvider but they are marked for deletion (`deletion_scheduled`), ArgoCD tries to clone them and fails with `error creating SSH agent: SSH_AUTH_SOCK not-specified`. This is transient — it resolves when the repos finish deletion or new repos are created.

### GitOpsCluster placement namespace
The `GitOpsCluster` CR MUST be in `openshift-gitops` (same namespace as the ACM `Placement`), NOT in `vp-gitops`. But `spec.argoServer.argoNamespace` MUST point to `vp-gitops` (where the VP-managed ArgoCD instance lives). Without this split, ArgoCD never discovers spoke clusters.

### ExternalSecret API version
Use `external-secrets.io/v1` (not `v1beta1`). The ESO operator on OCP 4.20 does not serve `v1beta1` by default. Using the wrong version causes `no matches for kind "ExternalSecret"`.

### Gateway API HA replicas
Istio Gateway API does not support `spec.replicas` directly. Use `spec.infrastructure.parametersRef` pointing to a ConfigMap:
```yaml
spec:
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: neuroface-gateway-infrastructure
```
The ConfigMap contains `deployment: | spec: replicas: 2`. This works on both hub and spokes.

### OwnerPicker entity ref format
The Backstage `OwnerPicker` field returns `user:default/user1`, not `user1`. Use the Nunjucks filter `parseEntityRef | pick('name')` throughout the template to extract just the username. Without this, repo names and namespaces contain `user-default-user1` instead of `user1`.

## Lessons learned from workshop deployment and spoke onboarding (Jun 29, 2026)

### GitLab 500 on session login (namespace_settings nil)
In GitLab 18+, groups created programmatically via `gitlab-rails runner` do NOT auto-create `namespace_settings`. When a user logs in and accesses a group page, GitLab calls `namespace_settings` which returns nil and triggers a 500.
**Fix**: Call `create_namespace_settings!` on every group in the `ensure_group()` function inside `charts/all/gitlab-operator/templates/job-gitlab-bootstrap.yaml`. Also add an `ensure_developer()` function to grant Developer role to all workshop users on the `ws-workshop` group.

### Keycloak CrashLoopBackOff (ambient mesh breaks DNS)
Adding Istio ambient mesh labels (`istio.io/dataplane-mode: ambient`) to `keycloak-system` namespace causes DNS resolution failures inside Keycloak pods (`UnknownHostException: postgresql-db`). The ztunnel proxy intercepts DNS before CoreDNS responds.
**Fix**: Do NOT add ambient mesh labels to `keycloak-system` namespace in `values-hub.yaml`. Keycloak must remain outside the mesh.

### SSO hostname mismatch (cookie domain)
The Keycloak CR defaults to `hostname: keycloak.apps.<domain>` but the AuthPolicy `extAuth` redirects users to `sso.apps.<domain>`. This mismatch causes "Restart login cookie not found" because cookies are scoped to the wrong hostname.
**Fix**: Override `keycloak.ingress.hostname` (not `keycloak.hostname` — ignored by upstream rhbk) to `sso.{{ .Values.global.localClusterDomain }}` in `values-hub.yaml` so Keycloak issues cookies/tokens on `sso.<apps-domain>`. Empty ingress hostname falls back to `keycloak.<domain>`; a wrong key left Cluster Bot installs on `keycloak.apps.example.com`. Update console links to use `sso.<domain>` as well.

### OIDC blocking frontend API calls
AuthPolicy on `neuroface-app-lb` HTTPRoute blocks XHR calls to `/api/health` (and other backend endpoints). The frontend badge logic needs `/api/health` to determine cluster identity (HUB/EAST/WEST).
**Fix**: Add `kuadrant.oidc.enabled` flag (default `false`) in the neuroface-gateway chart. When false, exclude `neuroface-app-lb` from gateway OIDC realms list. Keep OIDC only on `neuroface-cv-lb` (the CV inference route).

### YOLO PPE S3 403 (Minio credential mismatch)
GitLab's bundled Minio auto-generates access keys at install time. Hardcoded `minio/minio123` credentials in the YOLO PPE inference container don't match.
**Fix**: Set `useVault: true` in `spoke-neuroface-cv` values for model storage. Add Minio credential extraction and Vault sync to the `gitlab-bootstrap` job so the real credentials propagate to spokes via ESO.

### East spoke deployment blockers
Multiple issues deploying spokes:
- `vault` namespace missing on spoke (ESO fails)
- Duplicate Job resources: ArgoCD hook annotations (`argocd.argoproj.io/hook: PostSync`) cause ArgoCD to count them separately from the regular Job, creating conflicts
- `istio-system` namespace not auto-created on spokes (Istio operator expects it)

**Fix**: Remove ArgoCD hook annotations from the `download-model` Job (let it run as a normal sync resource). Pre-create missing namespaces (`vault`, `istio-system`) in `clusterGroup.namespaces`. For manual emergency deploys: `helm template charts/all/spoke-neuroface-cv | oc apply -f -`.

### Skupper east connection
Spokes need a Skupper `Site` CR and an `AccessToken` to link back to the hub. The `hub-interconnect` chart has an `accesstoken-sync` CronJob that pushes tokens to spokes via ACM `ManagedClusterAction`. Verify the CronJob runs successfully after spoke import completes.

### Rate limiting
Default Kuadrant `RateLimitPolicy` of 30 req/min is too low for the demo (multiple users hitting the CV inference endpoint simultaneously). Increased to 120 req/min in `neuroface-gateway/values.yaml`.

## Lessons learned from OIDC self-service, live-incident response, and systematic bug-hunting (Jul 1, 2026)

### Duplicate cluster-singleton CRs caused a full security outage
`neuroface-gateway` and `workshop-kuadrant-apis` each declared their own `Kuadrant` CR (in different namespaces) plus their own `Authorino`/`Limitador` CRs. The kuadrant-operator always deploys the managed Authorino/Limitador into its own install namespace (`redhat-connectivity-link-operator`) regardless of which `Kuadrant` CR's namespace triggered it, so the two declarations raced for the same underlying objects. When one Application got recreated during a routine ArgoCD sync, it took down Authorino/Limitador **cluster-wide** — every `AuthPolicy`/`RateLimitPolicy` in the cluster (NeuroFace CV OIDC, AI Gateway auth, workshop API rate limits) started failing with 500s until manually restored.
**Fix**: declare cluster-singleton CRs (Kuadrant, Authorino, Limitador, DataScienceCluster, Kiali, etc.) in exactly ONE chart. Never let two Applications both create "the" instance of something the underlying operator treats as global.
**Prevention technique** — systematic duplicate-object scan: render every local chart with `helm template` (once with `clusterRole=hub`, once with `clusterRole=spoke`, supplying dummy `global.*` values) and cross-reference every `(kind, namespace, name)` tuple across all chart outputs. Any tuple produced by more than one chart is a latent version of this exact bug.

### Duplicate Subscription silently strips resource-limit overrides
`values-hub.yaml`'s `clusterGroup.subscriptions.gitlab` (rendered by the shared `clustergroup` chart, which only supports `spec.config.env`) and `charts/all/gitlab-operator/templates/subscriptions.yaml` (which supports `spec.config.resources`, needed because gitlab-operator's OLM default 300Mi limit OOMs while reconciling the full GitLab chart) both targeted the same `Subscription` object. The clustergroup-rendered one always won and silently stripped the `config.resources` override on every sync, leaving the operator permanently CrashLoopBackOff.
**Fix**: if a local chart needs `spec.config.resources` (or any field the shared `clustergroup` chart's Subscription template does not render — it only supports `name/namespace/channel/source/config.env`), do NOT also declare that Subscription under `clusterGroup.subscriptions` in the values file. Pick exactly one owner.

### KeycloakRealmImport does not reconcile existing realms
Adding a new client to `spec.realm.clients` in a `KeycloakRealmImport` has **no effect** if the realm already exists in the cluster (confirmed: the operator only imports on first creation). For any realm/client change on a live cluster, create/update it directly via the Keycloak Admin REST API, then keep the Helm source updated for future fresh installs (which do get the client, since the realm doesn't exist yet there).

### KeycloakRealmImport placeholders require backing Secrets to exist BEFORE import — PostSync Jobs fix the race
The `$(PLACEHOLDER_NAME)` mechanism in `KeycloakRealmImport` resolves secrets at import time only. If the backing K8s Secret (from ESO/Vault) is not yet synced when the operator processes the import, the literal placeholder string (e.g. `$(CLIENT_SECRET_USER1)`) is stored as the actual client secret in Keycloak — causing `unauthorized_client (Invalid client or Invalid client credentials)` on every OAuth/OIDC flow until manually fixed. This is a **race condition inherent to the Keycloak operator's design** (one-shot import, no reconcile), not a sync-wave ordering issue (ESO may take seconds-to-minutes after the Secret Store connects).
**Fix**: PostSync Jobs that idempotently read the real secret from the K8s Secret and PUT it into Keycloak via Admin REST API after every ArgoCD sync:
- `charts/all/rhbk-iam/templates/job-sync-client-secrets.yaml` — syncs all per-user clients (`client-{realm}-user{N}`) across cv/maas/neuroface realms plus the `backstage-provisioner` service account in cv
- `charts/all/developer-hub/templates/job-sync-backstage-realm-secrets.yaml` — syncs `developer-hub`, `developer-hub-catalog`, `devspaces` clients in the backstage realm
Both Jobs are idempotent (skip if secret already matches), graceful (exit 0 if backing Secret not ready yet), and share the `rhbk-iam-secret-sync` ServiceAccount in `keycloak-system`.

### RHDH login secret must share the exact same Vault path as other clients using it
`keycloak-realm.yaml` had the `developer-hub` (login) client's secret rendered directly from a Helm value (`.Values.keycloakOidcClientSecret`), while RHDH's actual runtime `OIDC_CLIENT_SECRET` env var came from Vault via ExternalSecret. These diverged, causing `unauthorized_client (Invalid client or Invalid client credentials)` on every login attempt.
**Fix**: any Keycloak client whose secret RHDH (or another workload) reads from a Vault-backed Secret must resolve that same secret via the KeycloakRealmImport `spec.placeholders` mechanism (`$(PLACEHOLDER_NAME)` in the client's `secret:` field, backed by `secret: {name, key}` pointing at the SAME K8s Secret), never a separate hardcoded Helm value. See `charts/all/developer-hub/templates/keycloak-realm.yaml`.

### Scaffolder template `spec.output.text` schema
Backstage/RHDH scaffolder templates require `spec.output.text` to be an array of `{title, content}` objects, not plain strings. A template with `output.text: ["some string"]` is **silently rejected by the catalog processor** (`ScaffolderEntitiesProcessor` warning, `/spec/output/text/0 must be object`) — the template never appears in the catalog at all, with no error surfaced to a casual observer.

### RBAC gaps in hook Jobs that `oc exec`/`oc get pods -l` cross-namespace
Two hook Jobs (`gitlab-token-setup`, `job-gitlab-bootstrap`) execute into pods or list pods by label in a namespace their `Role` never granted `pods`/`pods/exec` for. One failed hard (`BackoffLimitExceeded`, blocking the whole app sync) because the script used `set -e` without guarding the failing command; the other failed silently (stderr redirected, checked with `if [ -n ... ]`) and just printed a misleading "WARN: could not write to Vault" on every run even though nothing was wrong.
**Prevention technique**: `grep -rl "oc exec\|oc get pods" charts/all/*/templates/*.yaml`, then for each hit, extract every `-n <namespace>` the script touches and confirm the Job's ServiceAccount has a `Role`/`RoleBinding` in that exact namespace (not just its own).

### Shared-namespace lists must not concat hub-only with spoke-only namespaces
`charts/all/observability/templates/all.yaml` built its Istio mesh monitoring namespace list by starting with the hub-only namespace (`neuroface-gateway-system`) and then, when `clusterSuffix` was set (i.e., on spokes), **concatenating** the spoke-only namespaces (`neuroface`, `neuroface-cv`) on top instead of replacing. Every spoke install tried (harmlessly, since the namespace doesn't exist there, but uselessly) to create a `PodMonitor`/`RoleBinding` in `neuroface-gateway-system`.
**Fix**: namespace sets that are mutually exclusive per cluster role must be selected with `if/else`, never built by concatenation.
**Prevention technique**: render every chart actually declared in `values-east.yaml`/`values-west.yaml` `clusterGroup.applications` with `clusterRole=spoke`, collect every `metadata.namespace`, and diff against `values-east.yaml`/`values-west.yaml` `clusterGroup.namespaces`. Anything used-but-undeclared is a bug (this is exactly how the `imperative` namespace gap — see `vp-helm-values` skill — and this one were both found).

### values-secret.yaml.template must declare every Vault path an ExternalSecret reads
A new feature's `ExternalSecret` (`keycloak/realms/cv/backstage-provisioner`) worked in the live cluster only because the secret was populated manually during development. It was never added to `values-secret.yaml.template`, so `./pattern.sh make load-secrets` on a fresh install would never create it.
**Prevention technique**: for every new `ExternalSecret`, grep its `remoteRef.key` + `remoteRef.property` and confirm a matching `secrets[].name` + `fields[].name` entry exists in `values-secret.yaml.template`. Do this for the whole file periodically, not just new additions — see the systematic script in the `vp-helm-values` skill's pitfall list.

### CEL expressions in Kuadrant policies: single quotes for string literals
`request.headers["x-forwarded-for"]` (double quotes) in a `RateLimitPolicy` counter expression crashes Limitador (`Invalid limit file: ... Syntax error`, CrashLoopBackOff) because Limitador's descriptor-file serialization mangles a double-quoted string literal nested inside an already double-quoted CEL expression. Use single quotes: `request.headers['x-forwarded-for']`.

### Windows/git-bash environment notes (when operating this repo from Cursor on Windows)
- `oc exec ... -- sh -c '...'` (not a bare path) avoids git-bash mangling a leading `/` into a Windows drive path.
- Redirect command output to a relative path (`./tmp-work/file.yaml`) with `working_directory` set explicitly, not `/tmp/...` — git-bash sometimes translates `/tmp` to `C:/Program Files/Git/tmp` depending on the tool invocation path.
- Files extracted from a live ConfigMap via `oc get -o jsonpath` on Windows can pick up CRLF line endings; strip `\r\n` → `\n` before re-applying as a `data` key, or `oc apply`/`oc patch` may silently place the content under `binaryData` instead of `data`.

## Lessons learned from Backstage proxy auth + third duplicate-singleton-CR incident (Jul 1, 2026)

### Backstage's proxy plugin silently drops the Authorization header unless allowlisted
The `oidc-credentials-self-service` scaffolder template authenticates against Keycloak (`/proxy/keycloak/.../token`, no auth needed) and then calls Keycloak's Admin REST API (`/proxy/keycloak/admin/realms/cv/clients`) with `headers.Authorization: Bearer <token-from-step-1>`. Every one of those admin-API steps failed with a **real** (Keycloak-issued) `401 {"error":"HTTP 401 Unauthorized"}`, not a Backstage auth error — Keycloak was receiving the request with no `Authorization` header at all.
**Root cause**: Backstage's proxy-backend plugin only forwards "CORS-safe" headers to the proxy target by default; `Authorization` is intentionally excluded unless the endpoint config adds `allowedHeaders: ['Authorization']` (and normally also `credentials: forward`/`dangerously-allow-unauthenticated`). This is *silent* — no error in RHDH logs, the caller just gets whatever the upstream target replies for "no credentials".
**Diagnosis technique that cut through it fast**: fetch a token, then compare `curl -H "Authorization: Bearer $T" <target-direct>` (200) vs `curl -H "Authorization: Bearer $T" https://developer-hub.../api/proxy/<endpoint>` (401) vs the SAME proxied call with no header at all (401, identical body). If the with-header and without-header proxied responses are byte-identical, the proxy is dropping the header — check `allowedHeaders` on that `proxy.endpoints` entry.
**Fix**: any `proxy.endpoints.'/x'` block whose callers need to pass a dynamic, per-request Bearer token through to the target (as opposed to a static one baked in via `headers: {Authorization: ${ENV}}`) needs `allowedHeaders: ['Authorization']` explicitly.

### Third instance of the "two charts, one cluster-singleton CR" bug: Kiali
`charts/all/observability` declared its own `Kiali` CR (`name: kiali`, `openshift-cluster-observability-operator` namespace, `cluster_wide_access: true`) *and* the external validatedpatterns `servicemesh` chart (the `servicemesh-config` Application, chart pulled straight from `https://charts.validatedpatterns.io`, **not** vendored locally) already provisions its own cluster-wide `Kiali/default` in `istio-system`. The Kiali operator only allows one `cluster_wide_access: true` instance cluster-wide, so ours always lost (`status.conditions[type=Failure]`: `"already installed with deployment.cluster_wide_access set to true"`) and never got a Route. Both charts *also* separately declared the identical cluster-scoped `ClusterRoleBinding/kiali-monitoring-rbac` (same name, different `subjects[].namespace`), so the two Applications fought over its `subjects` on every sync.
Three other places had the dead route's hostname hardcoded and needed fixing in lockstep: `console-links` (the "Kiali Service Mesh" ConsoleLink), and `developer-hub.kialiEndpoint` helper (feeds the in-app Kiali plugin's `url`, the `dynamic-plugins-rhdh` Kiali backend provider `url`, and the `plugin-readiness` hook's Kiali reachability probe — the readiness Job kept failing `DeadlineExceeded` and blocking every future ArgoCD sync of `developer-hub` until this was found).
**Fix**: deleted our `Kiali` CR + its `ClusterRoleBinding`; pointed the helper/console-link at `kiali-<clusterRole-namespace>` i.e. `kiali-istio-system`.
**Prevention technique**: when a chart is sourced from an *external* Helm repo (`repoURL` under `charts.validatedpatterns.io` or similar, not `path: charts/all/...`), you cannot `grep` it locally — `helm pull <chart> --repo <url> --untar` it into `/tmp` (or `--version` if the exact version is pinned in `values-*.yaml`'s `chartVersion`) and diff its rendered `kind`s/names against every local chart, same as the local-only scan in the "Duplicate cluster-singleton CRs" lesson above.

### Gate demo-only `customResources` entries behind a real values flag, not a namespace collision
`configmap-app-config-rhdh.yaml`'s `kubernetes.customResources` unconditionally listed Strimzi (`Kafka*`) and Camel K (`Integration`/`Kamelet`/`Pipe`) GVKs, neither of which this pattern installs by default. RHDH's kubernetes-plugin queries the *entire* configured list for every namespace tied to a Topology-visible entity, so every entity in `neuroface-gateway-system` produced 4 Strimzi + 3 Camel `NOT_FOUND` 404s in the Topology view forever. There was already a `plugins.kafka.enabled: false` values key... just nested one level too deep inside `iamCatalog:` (dead weight, nothing ever read `iamCatalog.kafka`), one screen-scroll below the real `plugins:` block, easy to miss.
**Fix**: moved `kafka`/`camel` to genuine top-level values keys and wrapped both CR groups in `{{- if .Values.kafka.enabled }}` / `{{- if .Values.camel.enabled }}`.
**Also caught in the same customResources block**: `tokenratelimitpolicies.kuadrant.io` was configured at `apiVersion: v1`, but `oc get crd tokenratelimitpolicies.kuadrant.io -o jsonpath='{.spec.versions[*].name}: served={.spec.versions[*].served}'` showed only `v1alpha1` is `served: true` (unlike `authpolicies`/`ratelimitpolicies`, already on `v1`) — a version bump landed in the CRD schema without yet flipping `served: true`, and nobody re-checked the sibling `customResources` entries when adding it.
**Prevention technique**: for every `kubernetes.customResources` entry, `oc get crd <plural>.<group> -o jsonpath='{range .spec.versions[*]}{.name}: served={.served}{"\n"}{end}'` and confirm the configured `apiVersion` is actually `served: true` — don't assume it matches siblings in the same group.

### After an argocd-application-controller pod restart, sync retries can look "stuck" for several minutes — this is normal
Mid-session the `vp-gitops-application-controller-0` StatefulSet pod restarted (unrelated to anything we changed). For the next ~5-10 minutes every `Application` showed `operationState.phase: Running` with no progress and no new hook Jobs, because the controller was silently replaying "Resuming in-progress operation" for *every* Application in the cluster (visible in its logs) before it got to ours. `argocd app terminate-op <app>` (run via `oc exec deploy/<argocd>-server -- sh -c 'export ARGOCD_OPTS=--core; argocd app terminate-op <app>'`, since there's no local `argocd` CLI) followed by a plain re-sync got it unstuck once the controller had actually caught up — don't terminate-op immediately on the first sign of "stuck", it can make things worse mid-catch-up.
**If you need the fix live *now* and don't want to wait on ArgoCD**: `helm template <chart> -f <same values files as the Application's spec.source.helm.valueFiles> --set <same --set params from `oc get application <app> -o jsonpath='{.spec.source.helm.parameters}'`> --show-only <template>` reproduces the exact manifest ArgoCD would apply; `oc patch cm <name> --type merge --patch-file=<(...)` or `oc apply -f` it directly, then let ArgoCD converge (cosmetically) whenever it's ready. Note `oc patch --patch-file` on Windows/git-bash can mangle non-ASCII characters (em dashes, etc.) inside YAML comments even when the source `--patch-file` JSON was written with explicit UTF-8 — prefer plain ASCII (`--` not `—`) in any comment you expect to round-trip through a live patch, not just in the git source.
**Sharper danger from the same incident**: when that stuck operation *did* eventually complete, it applied a stale `operationState.syncResult.revision` pinned from *before* the current session's fixes — silently reverting a ConfigMap (`developer-hub-catalog-software-template-manifests`) to a several-commits-old, already-fixed-and-since-broken-again state. Check `.status.operationState.syncResult.revision` vs `git rev-parse HEAD` (or `.status.sync.revision`) any time an app was "stuck" before you touched it — a completed sync against an old revision can undo live hotfixes you already verified working, and the resulting symptom looks identical to "the fix was never applied" rather than "the fix was applied and then reverted".

### Any live `oc apply`/`oc patch` of a `.Files.Get | replace ...` templated ConfigMap must go through `helm template`, never the raw source file
Restoring `developer-hub-catalog-software-template-manifests` live (after the stale-revision revert above) by copying `charts/all/developer-hub/files/software-templates/oidc-credentials-self-service.yaml` straight into the ConfigMap reintroduced the *original* bug: that source file still contains unresolved `__KEYCLOAK_PROVISIONER_CLIENT_ID__`/`__KEYCLOAK_PROVISIONER_CLIENT_SECRET__` placeholders — the substitution happens in `catalog-software-template-manifests.yaml` (`{{ $.Files.Get ... | replace "__X__" $value }}`), not in the source file itself. The live template ended up sending literal `client_id=__KEYCLOAK_PROVISIONER_CLIENT_ID__` to Keycloak (`401 invalid_client`). Same trap a second time in the same incident: rendering with `helm template` but omitting `spokeCredentials.clusters.{east,west}.apiUrl` silently fell back to the chart's placeholder defaults (`cluster-east.example.com`), breaking the *other* template's (`ai-computer-vision`) spoke domain defaults, since I hadn't touched that file at all.
**Rule**: never `oc apply`/`oc patch` a raw `files/*` source file into a ConfigMap that's actually built by a `.Files.Get | replace ...` (or similar) Helm template — always `helm template` the *chart*, and pass **every** `--set` the real Application uses (check `oc get application <app> -o jsonpath='{.spec.source.helm.parameters}'` first), not just the ones you think matter for the file you're fixing. A partial `--set` list can quietly corrupt an unrelated key in the same rendered file.

### RHDH's embedded Swagger UI needs real CORS on every in-cluster gateway route, including preflight
Testing an API via RHDH's catalog "Try it out" means the browser calls the Gateway API route cross-origin from `developer-hub.<domain>`. None of this pattern's `HTTPRoute`s emitted any `Access-Control-Allow-*` headers, so every "Try it out" failed with a generic `TypeError: Failed to fetch` (confirmed root cause via `curl -H "Origin: https://developer-hub..." <route-url>` showing zero CORS headers -- rules out cert/network issues, which is what the error message's own "Possible Reasons" list suggests first).
**Fix**: a shared `<chart>.corsFilter` helper (one per chart: `neuroface-gateway`, `workshop-kuadrant-apis`) emitting a `ResponseHeaderModifier` filter with `Access-Control-Allow-Origin/-Methods/-Headers/-Credentials` and `-Max-Age`, added to every rule of every `HTTPRoute` a `kind: API`/`type: openapi` catalog entity's `servers:` points at. The installed Gateway API v1 `HTTPRoute` CRD only supports `RequestHeaderModifier`, `ResponseHeaderModifier`, `RequestMirror`, `RequestRedirect`, `URLRewrite`, `ExtensionRef` as filter types -- no native `CORS` filter (GEP-1767) yet, so `ResponseHeaderModifier` is the only lever available.
**Two traps found doing this systematically across all routes**:
1. **Use `set`, not `add`.** Some backends already emit their own CORS headers on `OPTIONS` specifically (confirmed on the neuroface app -- its `OPTIONS` handler echoes `Access-Control-Allow-Origin`/`-Credentials` dynamically, even though its normal `GET`/`POST` handlers don't). `add` on top of an existing header produces a duplicate value (e.g. two `Access-Control-Allow-Origin` entries), which is an *invalid* CORS response that browsers reject outright -- strictly worse than having no header at all. `set` always overwrites, regardless of what the backend does.
2. **A real preflight (`OPTIONS` with `Access-Control-Request-Headers`) needs a 2xx response, full stop** -- CORS headers alone don't save it. Any `AuthPolicy` requiring an API key on the *whole* route also rejects the browser's *unauthenticated* preflight `OPTIONS` with `401`, and any `OIDCPolicy` redirects it `302` -- both non-2xx, so the browser fails the CORS check before the real (authenticated) request is ever sent, even though the 401/302 response itself carries perfectly correct `Access-Control-Allow-*` headers. Core `kuadrant.io/v1 AuthPolicy` has a policy-wide `spec.when` (CEL predicates) that skips the whole policy when false -- add `when: [{predicate: 'request.method != "OPTIONS"'}]` to exempt preflight from auth without weakening the real request's auth at all (verified: actual `GET`/`POST` without a key still 401s). The `extensions.kuadrant.io/v1alpha1 OIDCPolicy` CRD has **no** such field (`spec` is just `auth`/`provider`/`targetRef` -- checked via `oc get crd oidcpolicies.extensions.kuadrant.io -o jsonpath=...`), so any OIDC-protected route's preflight for *custom-header* requests cannot be fixed without an upstream Kuadrant change; simple requests (no custom headers, e.g. a plain `GET`) still work since they never trigger a preflight.
**Prevention technique**: map every `kind: API`/`type: openapi` catalog entity's `servers:` URL to its owning `HTTPRoute`(s) (`grep -rn "servers:" -A2 charts/all/developer-hub/files/catalog/openapi/`), then for each one check both a plain `curl -H "Origin: ..."` (does the actual response carry headers?) *and* a synthetic preflight `curl -X OPTIONS -H "Origin: ..." -H "Access-Control-Request-Method: ..." -H "Access-Control-Request-Headers: authorization"` (does the preflight itself come back 2xx?) -- the two can fail independently and need different fixes (route-level `ResponseHeaderModifier` vs. policy-level `when` exemption).

### `extensions.kuadrant.io OIDCPolicy` has no `when`/exemption field -- swap it for core `AuthPolicy` + `identity.jwt` on API-only routes
`OIDCPolicy` (the Kuadrant extensions CRD implementing browser redirect-to-login, cookie sessions, etc.) has `spec: {auth, provider, targetRef}` only -- no `when` (checked via `oc get crd oidcpolicies.extensions.kuadrant.io -o jsonpath=...`), so its `OPTIONS` preflight always gets whatever the *real* enforcement path produces (a `302` login redirect in our case), which fails CORS just like a `401` would -- browsers require a `2xx` preflight response, full stop, regardless of which `Access-Control-Allow-*` headers are present.
**When it's safe to swap**: if the target `HTTPRoute` serves no interactive browser UI (every rule of `neuroface-cv-lb` rewrites to an API path, no frontend), the redirect-to-login behavior was never actually needed -- callers use a Bearer token (e.g. from the OIDC self-service scaffolder template), not a browser session. Core `kuadrant.io/v1 AuthPolicy` supports `rules.authentication.<name>.jwt.issuerUrl` (same OIDC-issuer/JWKS-based token validation Authorino uses internally for `OIDCPolicy` too, just without the redirect flow) *and* a policy-wide `spec.when` -- add `when: [{predicate: 'request.method != "OPTIONS"'}]` to exempt preflight, same pattern as the `AuthPolicy` fix above. Net result: unauthenticated requests 401 instead of redirecting to a login page that doesn't exist for this route anyway -- a UX improvement, not a regression.
**Bug this surfaced along the way**: Authorino's OIDC discovery does *strict* issuer matching -- the `.well-known/openid-configuration` document's `issuer` field must exactly equal the configured `issuerUrl`, or every token gets rejected with `oidc: issuer did not match the issuer returned by provider`. Keycloak has *two* routes to the same instance here (`sso.<domain>` and the operator-managed `keycloak.<domain>`, matching `Keycloak` CR's `spec.hostname.hostname`) -- `sso.<domain>` works fine for reaching every endpoint (token, admin API, etc.), but Keycloak's own `iss` claim on every token (and its discovery doc) always says `keycloak.<domain>`, since that's the ONE canonical hostname it's configured with, regardless of which route you used to ask. Any *strict* OIDC/JWT consumer (Authorino `AuthPolicy`/`OIDCPolicy`, or anything else doing real discovery-based issuer validation) must use `keycloak.<domain>` as `issuerUrl`, not `sso.<domain>` -- check via Authorino's own pod logs (`oc logs -n redhat-connectivity-link-operator <authorino-pod>`) for `"failed to discovery openid connect configuration"` if a JWT AuthPolicy that "should" work keeps 401ing.
**Genuine remaining limitation found by this exercise (later fixed, see below)**: even with the policy-level `when` exemption working (confirmed: Authorino now lets `OPTIONS` straight through), the upstream *application* itself can still break preflight -- `neuroface-cv`'s backend returns a proper `405 Method Not Allowed` for `OPTIONS /health` (unlike `neuroface-app`'s backend, which happens to answer `OPTIONS` the same as `GET`/any other method). A `405` is just as fatal to a real browser preflight as a `401`/`302` would be. Gateway API `HTTPRoute` filters can't synthesize a canned `2xx` response before the backend is reached (no "direct response" filter type in this CRD version -- see the CORS pitfall above for the full filter-type list); simple requests (no custom headers, so no preflight is ever triggered) worked fine regardless, but this blocked *every* authenticated Swagger UI "Try it out" once the OAuth2 Authorize flow started attaching real `Authorization` headers -- demo-blocking, not just a nice-to-have.

### Fixing a Gateway API filter gap with an EnvoyFilter direct-response, without duplicating the HTTPRoute's own CORS headers
Fixed the `405`-on-`OPTIONS` gap above with an `EnvoyFilter` (`charts/all/neuroface-gateway/templates/envoyfilter-cors-preflight.yaml`), `workloadSelector` on the Gateway's own workload, inserting a Lua HTTP filter that short-circuits any `OPTIONS` request with a plain `204` via `request_handle:respond(...)`.
**Non-obvious part**: route matching (and therefore each `HTTPRoute`'s own `ResponseHeaderModifier` CORS filter) *still runs* even for a response generated locally by an earlier filter's `respond()` call, since it happens on the response-encoding path, not the request-routing path. Setting the same `Access-Control-Allow-*` headers *inside* the Lua reply too (seemed like the obvious thing to do, seeing as `respond()` accepts a headers table) produced **duplicate, comma-joined header values** (`access-control-allow-origin: https://x,https://x`) -- itself an invalid CORS response that fails the same way a missing header does. Fix: let the Lua filter *only* set the status code; leave all CORS headers to the existing route-level filters.
**Anchor the EnvoyFilter patch precisely**: `applyTo: HTTP_FILTER` / `INSERT_BEFORE` needs a `subFilter: {name: envoy.filters.http.router}` under the network filter match, not just the network filter (`envoy.filters.network.http_connection_manager`) alone -- omitting `subFilter` produced duplicated headers too (in that version of the mistake, from the Lua filter itself apparently being wired in more than once), same visible symptom as the above but a different cause; always sanity-check with a real preflight `curl` for duplicate header values after applying *any* EnvoyFilter that touches the HTTP filter chain.

### Helm `range` rebinds `.` to the loop item -- `include "chart.helper" .` inside a range silently breaks any helper reading `.Values`
`workshop-kuadrant-apis/templates/routes.yaml` calls a shared corsFilter helper from inside `{{- range $name, $api := .Values.apis }}`. Using `.` (instead of `$`) for the `include` context there panics with `nil pointer evaluating interface {}.global`, because inside the range body `.` is rebound to the current map value (`$api`, e.g. `{enabled: true, host: ...}`), not the chart root -- so `.Values` inside the helper resolves against `$api.Values` (undefined) instead of the real root `.Values`. Always pass `$` (the root context, captured automatically by Helm/Go templates) to any `include`/`template` call made from inside a `range`, `with`, or any other block that rebinds `.`.

### Kuadrant `AuthPolicy` can validate two independent identity sources on one route -- Authorino ORs them
When a survey of every `type: openapi` catalog entity turned up that `neuroface-openapi`/`neuroface-cv-openapi` had OAuth2ClientCredentials Swagger auth (per the earlier CORS-preflight work) but `maas-openapi` only offered OIDC in *docs* while the live `ai-maas-auth` `AuthPolicy` on `HTTPRoute ai-maas` actually only accepted a Kuadrant APIKEY (a disabled, never-turned-on `oidcpolicy-maas.yaml` OIDCPolicy sat dormant behind `keycloak.realms.enabled: false`, itself using the wrong CRD per the "OIDCPolicy vs AuthPolicy for API-only routes" lesson above, and the wrong `sso.<domain>` issuer host per the strict-issuer-matching lesson) -- making the OIDC option in Swagger UI's Authorize dialog fetch a token that would then 401 on the real call. **Fix**: `rules.authentication` on a single `kuadrant.io/v1 AuthPolicy` accepts multiple named identity sources (`api-key-users: {apiKey: ...}` and `jwt-users: {jwt: {issuerUrl: ...}}` side by side); Authorino evaluates all of them and lets the request through if *any one* succeeds -- no `oneOf`/priority config needed, this is the built-in OR semantics. Deleted the dormant `oidcpolicy-maas.yaml` + its unused `externalsecret-keycloak-clients.yaml` (a second, redundant sync of client secrets `rhbk-iam` already provisions) rather than leaving dead, wrongly-configured code paths behind a flag nobody flips.
**Authorization/rate-limit rego and CEL must tolerate a *shape-varying* `auth.identity`** once two identity sources exist: an apiKey identity carries `metadata.annotations` (from the backing Kubernetes Secret); a JWT identity is the flat token claims (`iss`, `sub`, etc.) with no `metadata` key at all. Existing Rego (`object.get(input.auth.identity.metadata.annotations, "x", "")`) already degrades gracefully to `undefined` (not a hard error) when `.metadata` doesn't exist -- Rego propagates `undefined` through builtin calls rather than throwing -- so it was safe to just add one more `allow { input.auth.identity.iss }` rule for the JWT case. Kuadrant `PlanPolicy`/`TokenRateLimitPolicy` predicates use CEL instead, which is stricter about missing map keys; guard every access to `auth.identity.metadata.*` with an explicit `has(auth.identity.metadata) &&` before it, and give the JWT path its own tier/counter (`auth.identity.sub`, a claim guaranteed on every OIDC token) rather than reusing `auth.identity.userid` (an apiKey-only field) for both.

### Backstage's `POST /api/notifications` cannot be called from a scaffolder template step -- ever
`http:backstage:request` (roadiehq) can only carry `user`-derived credentials (either the initiator's plugin-request-token, or the raw `backstageToken` via `useBackstageToken: true` -- both are `user` principals). `@backstage/plugin-notifications-backend`'s create-notification route (`POST /` and `POST /notifications`) requires `allow: ["service"]` (confirmed in `.../plugin-notifications-backend/dist/service/router.cjs.js`), rejecting every `user`-principal call with `403 NotAllowedError: This endpoint does not allow 'user' credentials`. This is not fixable via proxy/header config (unlike the Authorization-forwarding pitfall above) -- it is a hardcoded `allow` list in an installed npm package. The only two ways to actually send a notification from a template are (a) show the payload directly in `spec.output.text` instead (no new dependency, works today), or (b) add `@backstage/plugin-scaffolder-backend-module-notifications` (the `notification:send` action, which runs in-process with real service credentials) as a dynamic plugin -- note this package is **not** available in RHDH's `rhdh-plugin-export-overlays` OCI registry (that repo only re-hosts *community* plugins), so it would have to be fetched straight from the public npm registry, which needs its own verification (registry egress, version compatibility with the running Backstage core version) before relying on it.

### Singleton ArgoCD CR `spec.rbac` (and much of the rest of `spec`) reverts continuously — mechanism differs on hub vs. spokes (CONFIRMED both, corrected from an earlier wrong hub theory)
Two **different** mechanisms cause the same symptom, and it's important not to conflate them:

- **East/west spokes (CONFIRMED)**: the published VP `acm` chart (`charts.validatedpatterns.io/acm`, checked through the latest published `0.2.8`) creates, per entry in `clusterGroup.managedClusterGroups`, a `Policy`/`ConfigurationPolicy` (`{clusterGroup}-gitops-policy-argocd`, e.g. `east-gitops-policy-argocd`) with `remediationAction: enforce` and `complianceType: mustonlyhave` for the full spoke `ArgoCD` CR spec, including a **hardcoded** `spec.rbac: {defaultPolicy: role:readonly, policy: "g, system:cluster-admins/cluster-admins/admin, role:admin", scopes: [groups,email]}` with **no values override key anywhere in the chart** (verified by pulling and reading the chart source directly: `templates/policies/ocp-gitops-policy.yaml`, not just its README). Confirmed live: `oc get policy -A` shows exactly `east-gitops-policy-argocd`/`west-gitops-policy-argocd` (and no equivalent for `hub`).
- **Hub (CONFIRMED, exact source line, upstream issue filed)**: the hub is **not** a member of `clusterGroup.managedClusterGroups` (that value only lists `east`/`west` in `values-hub.yaml`), so **no ACM Policy targets the hub's own `vp-gitops` ArgoCD CR at all** — verified via `oc get application acm -n vp-gitops` resource list (only east/west `Policy`/`Placement`/`PlacementBinding` objects, zero for hub) and via `clusterGroup-chart`'s `templates/plumbing/argocd.yaml`, whose `{{- if $.Values.global.singleArgoCD }}{{- else }}...{{- end }}` branch renders nothing at all in singleArgoCD mode either. It is **`patterns-operator` itself** (not `openshift-gitops-operator`, though that operator's own downstream reconcile is what actually restarts pods — see below): `internal/controller/pattern_controller.go`'s main `Reconcile` calls `createOrUpdateArgoCD(r.dynamicClient, r.fullClient, getClusterWideArgoName(), clusterWideNS, patternsOperatorConfig)` **unconditionally on every reconcile pass** (comment in the source: `// We only update the clusterwide argo instance so we can define our own 'initcontainers' section`). `createOrUpdateArgoCD` (`internal/controller/argo.go`) always rebuilds the full desired spec via `newArgoCD(...)` (hardcoded baseline including `RBAC: argooperator.ArgoCDRBACSpec{DefaultPolicy: &defaultPolicy, Policy: &argoPolicy, Scopes: &argoScopes}` — `role:readonly` + a 3-line policy granting only `system:cluster-admins`/`cluster-admins`/`admin` -> `role:admin`, no override hook of any kind) and, when the object exists, calls a **plain `client.Resource(gvr).Namespace(namespace).Update(...)` with no diff check against the live object first** — this matches the field-manager `manager` (controller-runtime's default identity for a client that doesn't set a custom field owner) doing `operation: Update` (not `ServerSideApply`/`Apply`) observed live via `--show-managed-fields`. Because the operator also reacts to its own write (directly or transitively), this creates a **self-sustaining fast reconcile loop** far quicker than the documented steady-state `ReconcileLoopRequeueTime` (180s) — confirmed live: `oc get argocd vp-gitops -n vp-gitops -o jsonpath='{.metadata.resourceVersion}'` polled every ~10-15s with **nobody else touching the object** keeps incrementing; scaling `patterns-operator-controller-manager` to 0 replicas made `resourceVersion` immediately stop changing (stable 90+s), and scaling back to 1 replica resumed the churn on the very next reconcile — a clean, decisive A/B test, not circumstantial correlation. `openshift-gitops-operator`'s own controller reacts to each Update by recomputing/reapplying the Deployments/StatefulSet it manages ("Updating StatefulSet ... updating volumes/container resources/command/env", "Updating Deployment 'vp-gitops-redis/repo-server/server/applicationset-controller' - updating volumes/...") roughly every 15-30s, restarting the `<name>-application-controller` pod on that cadence and leaving in-flight `Application` syncs stuck in `operationState.phase: Running` for extended periods (observed 1+ hour on one Application). **Filed upstream**: [validatedpatterns/patterns-operator#749](https://github.com/validatedpatterns/patterns-operator/issues/749), with full reproduction, the exact source lines, and a suggested fix (add a diff check before calling `Update()` in `createOrUpdateArgoCD`, plus an override hook for `spec.rbac` mirroring `clusterGroup.argoCD.rbac`). Nothing further to root-cause from a pattern repo's side — this is compiled into the operator binary (v0.0.77, the latest available in the `fast` channel as of this writing), not something a Helm chart or values file can influence.

Either way, `spec.localUsers` has no equivalent in either mechanism, so it is NOT touched and sticks reliably. **Practical impact**: a local user (e.g. `ai-agent` for the Argo CD MCP server) authenticates fine and can `get`/`list` Applications, but falls through to `defaultPolicy: role:readonly` (cannot `sync`) unless bound by name to one of the hardcoded/defaulted groups (`system:cluster-admins`, `cluster-admins`, `admin` only). This is either a genuine upstream Validated Patterns framework gap (spokes: no override key on the `acm` chart's policy template, mirroring how `clustergroup-chart` added `clusterGroup.argoCD.rbac` in v0.9.50 for the non-singleArgoCD path) or an `openshift-gitops-operator` defaulting quirk (hub) — not something fixable from a pattern repo today. Also causes the app-of-apps/`openshift-gitops` Applications to stay `OutOfSync`/`Running` indefinitely and the `vp-gitops-application-controller` StatefulSet pod to restart every ~15-30s on the hub (each operator "Update" of the full spec triggers Deployment/StatefulSet spec recomputation downstream) — this is a real, currently-unresolved source of Argo CD control-plane instability on the hub, independent of anything in this repo's own charts. **Verification recipe**: `oc get argocd vp-gitops -n vp-gitops -o yaml --show-managed-fields`; on spokes cross-check with `oc get policy -A | grep gitops-policy-argocd` and `helm pull acm --repo https://charts.validatedpatterns.io --untar` to read the policy template directly (its README only documents the non-singleArgoCD override keys, which don't apply here); on the hub, `oc logs -n openshift-gitops-operator deploy/openshift-gitops-operator-controller-manager --since=60s | grep "Updating StatefulSet\|Updating Deployment 'vp-gitops"` to see the downstream churn live.

### NEW (unresolved): OpenShift Lightspeed LLM health check fails with 500 via legacy `ai-gateway` — Kuadrant WASM can't reach Authorino gRPC
`lightspeed-app-server`'s main container (`lightspeed-service-api`) fails readiness (`2/3` ready) with `LLM connection check failed with - Internal Server Error` against `https://ai-gateway.apps.<cluster>/v1/chat/completions` (the legacy Istio-based `ai-gateway`/`ai-gateway-system` Gateway, chosen specifically because native MaaS's `data-science-gateway-class` has its own separate, already-documented WASM/Envoy incompatibility — see the entry below). Confirmed via direct `curl` with the correct Bearer token from `workshop-ai-gateway-credentials`: consistent `HTTP 500`. `ai-gateway-istio` pod logs show `wasm log kuadrant-wasm-shim kuadrant_wasm_shim: gRPC status code is not OK` on every request — the Kuadrant WASM filter cannot successfully dispatch its authorization gRPC call. **Ruled out**: no `NetworkPolicy` in `ai-gateway-system` or `redhat-connectivity-link-operator`; the (only) live `authorino`/`limitador` pair in `redhat-connectivity-link-operator` is `2/2 Running` and all ~30 `AuthConfig`s cluster-wide show `Ready: true, 1/1 hosts` — but `oc logs deploy/authorino` shows **zero** incoming requests correlated with the failing calls, meaning the WASM shim never successfully reaches it. A full `oc rollout restart deploy/ai-gateway-istio` does **not** fix it (ruled out stale/half-applied Envoy config from the same night's churn). **New lead, not yet chased down**: `authorino-operator.v1.4.1` CSV in `redhat-connectivity-link-operator` is stuck `Pending: one or more requirements couldn't be found` (an incomplete OLM upgrade from 1.4.0) — possibly unrelated to the running Authorino pods (which may predate the stuck upgrade), but worth checking first next session, along with the WASM shim's actual configured `grpc_service` target (check the `EnvoyFilter`/Istio `WasmPlugin`-equivalent that Kuadrant's operator generates for this specific `Gateway`, and compare its cluster/service/port against `authorino-authorino-authorization.redhat-connectivity-link-operator.svc:50051` — envoy's `/clusters` admin endpoint would confirm the actual configured target, not attempted here due to missing `curl`/`wget`/`nc` in the `istio-proxy` container). **Confirmed NOT caused by this session's changes**: predates tonight's rbac/ACM-policy work (unrelated namespaces/CRs) and survives a full gateway pod restart. **Practical impact**: OpenShift Lightspeed chat (both console plugin and the Argo CD MCP tool integration) cannot currently reach the LLM through this path — showroom module 10 content/screenshots should be re-verified against live chat responses before relying on it for a delivery.

### Native MaaS (RHOAI 3.4) + legacy AI Gateway run in parallel during migration
`openshift-ai-hub` sets `kserve.modelsAsService: Managed` when `maas.native.enabled=true`. Chart `models-as-a-service` (hub, wave 6) deploys `Tenant`, `ExternalModel`, `MaaSSubscription`, Gateway `maas-default-gateway`, and patches `OdhDashboardConfig` (`modelAsService`, `genAiStudio`, `maasAuthPolicies`). The legacy Kuadrant path (`workshop-kuadrant-apis.apis.maas.enabled`) stays enabled until native MaaS is validated — then disable legacy and optionally delete orphaned `Kuadrant` CR in `kuadrant-system`. **Authorino TLS** for native MaaS lives in `redhat-connectivity-link-operator` (not `kuadrant-system`); gateway TLS secret is `cert-manager-ingress-cert` in `openshift-ingress`. MaaS CR apiGroup is `maas.opendatahub.io/v1alpha1`.

### data-science-gateway-class WASM/Envoy version skew (RHCL 1.4.1 on RHPDS) — chart workaround
RHCL 1.4.1's Kuadrant WASM shim generates `allow_on_headers_stop_iteration`, which the `data-science-gateway-class` Envoy build in `openshift-ingress` (often v1.26.x on RHPDS) rejects — gateway pods (`maas-default-gateway`, `data-science-gateway`, `openshift-ai-inference`) crash-loop until WASM is removed. **Fix in repo**: `charts/all/models-as-a-service/templates/envoyfilter-wasm-fix.yaml`, gated by `gateway.wasmFix.enabled` (default `true`) and `gateway.wasmFix.injectMaasHeaders` (default `true`). The first EnvoyFilter REMOVES `envoy.filters.http.wasm` on all GATEWAY listeners in `openshift-ingress`; the second inserts a Lua filter on `maas-default-gateway` only, injecting `X-MaaS-Username` and `X-MaaS-Group` (JSON array) that `maas-api` still requires once Kuadrant auth no longer runs. **Trade-off**: Kuadrant AuthPolicy enforcement is lost on these gateways — acceptable on disposable sandboxes only. Istio version bumps on the GatewayClass are owned by RHOAI/Sail, not this pattern (`oc patch istio openshift-gateway` is reverted within seconds).

### APIKey approval gap (RHCL 1.4.1 developer-portal-controller absent) — scaffolder workaround
`APIProduct.approvalMode: automatic` does nothing when the DevPortal controller is not running — `APIKey` CRs stay `Pending` and consumer Secrets are never created. **Fix in repo**: Developer Hub scaffolder template `apikey-self-service` (`charts/all/developer-hub/files/software-templates/apikey-self-service.yaml`) — user picks a catalog API with `workshop/apikey-self-service-target: "true"`, template creates `APIKey` + labeled Secret + patches `status.phase: Approved` via `/api/proxy/k8s-api`. RBAC: existing `ClusterRole developer-hub-kuadrant`. Target API entities in `workshop-kuadrant-apis.yaml` carry `workshop/apikey-product-namespace`, `workshop/apikey-example-url`, and reuse `kuadrant.io/api-product` for Secret labels (`kuadrant.io/apikey`, `devportal.kuadrant.io/apikey-namespace`, `app`, `secret.kuadrant.io/plan-id`). **Post-create pitfall**: Authorino may need a rollout restart to index new Secrets if it started before they existed.

### Never bake a Vault-sourced secret into a git-tracked resource as a "matching" static default — ArgoCD selfHeal reverts any live patch within seconds
`oidc-credentials-self-service`/`oidc-credentials-revoke` used to embed `client_secret` for the `backstage-provisioner` client literally in the ConfigMap at Helm-render time (`catalog-software-template-manifests.yaml`'s `| replace "__KEYCLOAK_PROVISIONER_CLIENT_SECRET__" ($kp.clientSecret | default "backstage-provisioner-poc-2026")`), while `rhbk-iam`'s `job-sync-client-secrets.yaml` independently pushes whatever's in Vault (`secret/data/hub/keycloak/realms/cv/backstage-provisioner`) into Keycloak, falling back to that same hardcoded string only when Vault has no value. These two only matched by coincidence — the moment Vault holds a real (non-default) secret, Keycloak's actual secret and the ConfigMap's embedded literal diverge, and every self-service/revoke run 401s with `unauthorized_client`.
**First fix attempted (wrong)**: a PostSync Job reading Keycloak's live secret via Admin API and patching it into the already-rendered ConfigMap. This worked for exactly one sync cycle then silently reverted — `developer-hub`'s Argo CD `Application` has `syncPolicy.automated.selfHeal: true` (`oc get application developer-hub -n vp-gitops -o jsonpath='{.spec.syncPolicy}'`), which continuously diffs live state against the last rendered Git manifest and reverts ANY drift on a resource it owns, including a hook-patched `ConfigMap` — same failure class as every other "singleton ownership" pitfall in this doc, just triggered by a *Job* instead of a second competing chart.
**Actual fix**: never let the secret touch a chart-rendered, git-tracked resource at all. `keycloak-provisioner-credentials` (`externalsecret-keycloak-provisioner.yaml`) already reads the *same* Vault key live into a Secret mounted via `envFrom` on the Backstage backend container (`backstage-developer-hub.yaml`) — that Secret's value is inherently correct (both Keycloak's client secret and this env var come from the identical Vault path) and isn't tracked/diffed by ArgoCD as chart-rendered YAML content. Added a computed `KEYCLOAK_PROVISIONER_BASIC_AUTH` key (`base64(clientId:clientSecret)`, via ESO's `target.template` with Sprig `b64enc` on the Vault path, or plain Helm `b64enc` on the non-Vault fallback branch) and a new Backstage proxy endpoint `/keycloak-provisioner-token` (`configmap-app-config-rhdh.yaml`) that injects `Authorization: Basic ${KEYCLOAK_PROVISIONER_BASIC_AUTH}` — the SAME `${ENV_VAR}` substitution idiom already used for `/rhacs` (`Bearer ${RHACS_API_TOKEN}`) and `/k8s-api` (`Bearer ${K8S_SA_TOKEN}`), resolved from the container's live env at Backstage-backend-startup, not baked into any file ArgoCD diffs. The two templates' `get-token` step now POSTs bare `grant_type=client_credentials` (no `client_id`/`client_secret` in the body at all — Keycloak accepts HTTP Basic auth as a full substitute for both) to `/proxy/keycloak-provisioner-token/...` instead of `/proxy/keycloak/...`.
**General rule**: if a value can drift between two independent places that "should" match (a chart default vs. a live external system's state), don't try to keep both in sync by writing one from the other via a Job — pick ONE live source of truth and have every consumer read *from* it at use-time. For Kubernetes Secrets specifically, `envFrom`/`${VAR}` app-config substitution (resolved at backend-process-start, not Helm-render time) is the correct mechanism when the consumer is Backstage itself; PostSync Jobs are only safe for patching state in systems ArgoCD does NOT track as manifest content (e.g. Keycloak's own Admin API, as `job-sync-client-secrets.yaml` correctly does) — never for patching an ArgoCD-owned Kubernetes resource's spec/data back to something that disagrees with Git while `selfHeal: true` is set.

### `http:backstage:request` (roadiehq) auto-prefixes `/api` — never include it in `input.path`
Writing a new scaffolder template (`apikey-self-service.yaml`) that called `path: /api/catalog/entities/by-name/...` and `path: /api/proxy/k8s-api/...` produced a live 404 with the actual requested URL logged as `/api/api/catalog/entities/by-name/...` (`rootHttpRouter` access log) — the action always prepends `/api` to whatever `path` you give it, so any leading `/api/` in the template source is a guaranteed double-prefix 404. Every *working* template in this repo (`oidc-credentials-self-service.yaml`'s `/proxy/keycloak/...`) already omits it. **Rule**: `input.path` for `http:backstage:request` must start directly with the plugin id (`/proxy/...`, `/catalog/...`), never `/api/...`. A handful of older templates in this repo (`industrial-edge*.yaml`, `cnv-vm-workshop.yaml`) DO use the `/api/proxy/k8s-api/...` form and have not been re-verified against this finding — treat as suspect/untested until confirmed live, not as a counter-example.
**Debugging technique**: don't trust an unauthenticated `curl` from inside the backend pod to prove an entity/route "doesn't exist" — `plugins.rbac.enabled: true` (this chart's default) makes the catalog plugin return `404 NotFoundError` (not `401`/`403`) for entities an anonymous/no-token caller isn't allowed to see, which looks identical to a genuine 404. Confirm actual existence by querying the catalog's own Postgres DB directly instead (`oc exec <psql-pod> -- psql -U postgres -d backstage_plugin_catalog -c "SELECT entity_id, final_entity::jsonb->'metadata'->>'name' FROM final_entities WHERE ..."` — note the explicit `::jsonb` cast, the column is stored as `text`).

### Backstage scaffolder has no built-in `now`/random filter unless a plugin registers one as a template global
A template step used `${{ '' | now | replace(...) }}` to build a unique resource name and an ISO timestamp for a `status.reviewedAt`/`lastTransitionTime` field. `now` is not a Backstage "built-in" templating filter (Nunjucks-powered; built-ins are documented at https://backstage.io/docs/features/software-templates/templating-extensions/#built-in) — it only exists if a backend plugin calls `templating.addTemplateGlobals({ now: () => new Date().toISOString() })`, which this RHDH instance's installed plugin set does not do. `SecureTemplater`'s `callFilter` silently returns `''` for any unrecognized filter name (no error, no warning in logs) — the step still "succeeds", just with wrong/empty data, making this a **silent** failure class, not a crash. **Fix**: don't invent uniqueness/timestamps in the template at all when the underlying API already provides it — use Kubernetes' own `metadata.generateName` (server-assigned unique suffix on `POST`, real value read back from `steps['<id>'].output.body.metadata.name` in later steps) instead of computing a name, and use the server-assigned `metadata.uid` (a real per-object v4 UUID, present on every Kubernetes object without any extra config) instead of computing/needing a timestamp or a hand-rolled "random" value. Applies generally: prefer values the live system already generates over template-side pseudo-randomness that doesn't actually exist in this Backstage instance.

### Backstage's `/proxy/k8s-api` endpoint needs `secure: false` — the global `NODE_TLS_REJECT_UNAUTHORIZED=0` does not cover it
`https://kubernetes.default.svc`'s serving certificate is signed by the cluster's internal CA, which Node's default trust store doesn't include. `backstage-developer-hub.yaml` already sets `NODE_TLS_REJECT_UNAUTHORIZED: "0"` on the container (added for a different, unrelated reason), but the **proxy plugin's own HTTP client** (`http-proxy-middleware`) creates its own TLS agent and does not honor that process-wide env var — every request through `/proxy/k8s-api/...` failed with a generic, unhelpful `500` and an empty body (visible detail only in the backend's own logs: `[HPM] Error occurred while proxying request ... [SELF_SIGNED_CERT_IN_CHAIN]`, `logProvider`/access log alone just shows `500` with no body). **Fix**: add `secure: false` to that specific proxy endpoint's config in `configmap-app-config-rhdh.yaml` (a documented, standard Backstage `ProxyConfig` option — see https://backstage.io/api/stable/interfaces/_backstage_plugin-proxy-node.ProxyConfig.html — already used this way for self-signed ArgoCD/GitLab instances in community examples). This was a **pre-existing, latent bug** in shared infrastructure (the `/k8s-api` proxy predates `apikey-self-service.yaml`) that any template routing through it would have hit — worth grep'ing `path: .*proxy/k8s-api` across all templates after this fix to confirm none were silently relying on a workaround.
**Debugging technique**: a `500` from a Backstage proxy endpoint with an empty response body is uninformative from the client side (`curl`) alone — always check the backend pod's own logs (`oc logs <pod> -c backstage-backend --since=2m | grep -i proxy`) for the `[HPM] Error occurred while proxying request ...` line, which names the actual upstream connection failure (TLS, DNS, connection refused, timeout, etc.) that the generic 500 response hides.

### `APIKey.spec.requestedBy` is an object, and `status.conditions[].lastTransitionTime` is required — read the CRD schema, don't guess field shapes from memory
Two more `apikey-self-service.yaml` bugs only surfaced by actually POSTing through the fixed `/k8s-api` proxy (`oc get crd apikeys.devportal.kuadrant.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec}'` is the authoritative source, always check it directly rather than inferring from an earlier session's shell commands):
1. `spec.requestedBy` is `{email, userId}` (both required, `email` has a regex format check) — a bare string 422s with `spec.requestedBy in body must be of type object: "string"`.
2. `status.conditions[]` requires `lastTransitionTime` on every entry (standard Kubernetes condition convention) — omitting it (done here specifically to avoid the missing-`now`-filter problem above) 422s with `status.conditions[0].lastTransitionTime: Required value`. Fix: reuse the APIKey object's own server-assigned `metadata.creationTimestamp` from the `create-apikey` step's response body — already a real RFC3339 timestamp, no filter/global needed, and semantically fine since the whole task runs within seconds.
**Verification technique that caught both**: after fixing the `/k8s-api` `secure: false` bug, replayed all four `apikey-self-service.yaml` steps manually via `curl` from inside the Backstage pod (exact same proxy paths and JSON bodies the template renders), one step at a time, reading each response's real field values (`metadata.name`, `.uid`, `.creationTimestamp`) to feed into the next step — catching both 422s *before* asking the user to retry through the UI a third time. Clean up any test `APIKey`/`Secret` objects created this way afterward (`oc delete apikey/secret <name> -n <ns>`).

### Authorino's `apiKey` identity only loads Secrets at its OWN pod startup — no live pickup, confirmed empirically across 3 restart cycles
Even after every `apikey-self-service.yaml` bug above was fixed and a real key authenticated successfully once, the *next* real key minted through the template still 401ed with `"the API Key provided is invalid"` — Authorino's `identity.apiKey.selector` (a live Kubernetes label selector on Secrets, confirmed via `oc get authconfigs.authorino.kuadrant.io -o json`, NOT a static list) is documented/expected to dynamically track matching Secrets, but empirically does not pick up ones *created while it's already running*, regardless of:
- The `authorino-manager-role` ClusterRole only granting `get`/`list` on secrets (missing `watch`) — patched to add `watch`, confirmed the informer's Secret controller started cleanly afterward (`"Starting Controller","controllerKind":"Secret"`, no Forbidden errors) — did NOT fix it.
- Touching/annotating the already-existing Secret (a plain Kubernetes `Update` event, which informers reliably deliver) — did NOT fix it either.
- Only an actual `oc rollout restart deployment/authorino -n kuadrant-system` (forcing a fresh List() at startup) made a newly-created key start working, reproduced 3 separate times with 3 different keys.
**Conclusion**: this is a real gap in Authorino's `authconfig` reconciler — the Secret-watch handler doesn't map newly-*matching* Secrets (as opposed to updates to Secrets it already knows about) back to the owning AuthConfig for re-evaluation. Not something fixable via RBAC or from a pattern repo's side; track as an RHCL/Authorino platform limitation.
**Fix in repo**: `charts/all/workshop-kuadrant-apis/templates/authorino-apikey-secret-resync.yaml` — a PostSync Job + `*/2 * * * *` CronJob (same safety settings as `acm-argocd-openapi-fix.yaml`: `concurrencyPolicy: Forbid`, `startingDeadlineSeconds`, `activeDeadlineSeconds`) that compares Authorino's own pod `status.startTime` against the newest `kuadrant.io/apikey=true` Secret's `creationTimestamp` across all namespaces, and only restarts Authorino when the newest secret is actually newer — avoids disrupting every *other* AuthPolicy this one Authorino instance also enforces (neuroface, maas, httpbin, mcp, ...) on ticks where nothing changed. Worst-case latency for a newly self-service-minted key to start working: ~2 minutes (one CronJob tick), fully automatic, no admin action needed. Also kept the `authorino-manager-role` `watch` RBAC addition even though it alone didn't fix this — it's still the objectively correct permission for a controller that runs a Secret watch/informer, and may matter for a future Authorino version that does map newly-matching secrets correctly.
**Debugging technique for this class of bug**: when a fix seems to work once but not on a subsequent, supposedly-identical attempt, don't assume it's the same root cause recurring — isolate whether the *fix's precondition* (here: "Authorino was JUST restarted") still holds for the new attempt, by checking the actual pod start time (`oc get pods -n kuadrant-system -l authorino-resource=authorino -o jsonpath='{.status.startTime}'`) against the new resource's creation time, not just re-running the same manual workaround and declaring success.

### Same CORS-preflight-vs-external-backend fix needed on `workshop-apis-gateway`/`ai-gateway`, not just `neuroface-gateway`
Swagger UI's "Try it out" for `workshop-restcountries-openapi` (`POST /countries/cities` with a custom `Authorization: APIKEY ...` header, forcing a real preflight) failed client-side with a generic "Failed to fetch / CORS / Network Failure", even though the AuthPolicy already exempts `OPTIONS` (`when: request.method != "OPTIONS"`) and the HTTPRoute's own `corsFilter` helper already sets `Access-Control-Allow-*` on every response. Root cause was the exact same class of bug already fixed once for `neuroface-gateway` (see the CORS-preflight entries above), just with a *different* concrete failure mode: `curl -X OPTIONS` showed the CORS headers present but status `503 upstream connect error ... reset reason: connection termination` — these routes' backends are all external `ExternalName`/`ServiceEntry` targets (`countriesnow.space`, `httpbin.org`, the RHOAI Llama predictor), and at least `countriesnow.space` resets the connection outright for `OPTIONS` instead of the `405` seen on `neuroface-cv`'s own backend — same fatal-to-preflight outcome (any non-2xx fails a browser preflight), different upstream behavior producing it.
**Fix in repo**: `charts/all/workshop-kuadrant-apis/templates/envoyfilter-cors-preflight.yaml` — the identical Lua `respond({[":status"]="204"}, "")` short-circuit EnvoyFilter as `neuroface-gateway`'s, duplicated once per Gateway workload (`workshop-apis-gateway` in `workshopGateway.namespace`, `ai-gateway` in `aiGateway.namespace` — two separate `EnvoyFilter` objects since `workloadSelector` only matches one `gateway.networking.k8s.io/gateway-name` value each, and the two Gateways live in different namespaces). Verified live: preflight now `204` with correct singular (non-duplicated) `Access-Control-Allow-*` headers, and the real `POST` afterward still only carries one `access-control-allow-origin` header (confirms the Lua filter isn't itself adding CORS headers, avoiding the duplicate-header pitfall documented in the original neuroface fix).
**General takeaway**: any new Gateway/HTTPRoute fronting an *external* backend should be treated as CORS-preflight-suspect by default and checked with a real `curl -X OPTIONS -H "Access-Control-Request-Method: ..." -H "Access-Control-Request-Headers: authorization,content-type"` (not just a plain `GET`/`POST`) before wiring it into a Swagger UI catalog entry — don't wait for a user to report "Failed to fetch" in the browser to discover it.

### `countriesnow.space`'s own POST `/cities` endpoint redirects to a GET+query-param URL — rewrite the request, not the response
Even after the preflight fix above, real `POST /countries/cities` calls from Swagger UI still failed "Failed to fetch". Root cause, confirmed by calling `countriesnow.space` directly with no gateway involved at all: it unconditionally `301`s `POST /countries/cities` to `GET /countries/cities/q?country=<x>`. Envoy proxies that 301 back to the client unmodified (it doesn't follow upstream redirects); the `Location` value is a *relative* path with no scheme/host, so a browser's `fetch()` (which auto-follows redirects by default) resolves it against the current origin — i.e. back through *our own* gateway, at the upstream's *internal* path (`/api/v0.1/countries/cities/q?...`) that no `HTTPRoute` here matches. Envoy 404s that follow-up hop with **no** CORS headers at all (no route matched → the route-level `ResponseHeaderModifier` never runs), which a browser reports as a generic CORS/"Failed to fetch" error even though the original `301` itself carried correct `Access-Control-Allow-*` headers.
**First attempt (reverted, made it WORSE)**: an `envoy_on_response` Lua filter rewriting the `Location` header to re-enter at our own `/countries/...` prefix instead of the upstream's internal one. This produced an actual redirect **loop** — `countriesnow.space`'s own redirect handling isn't idempotent for this path shape; hitting its `/cities/q?country=X` endpoint again through our rewrite somehow made it 301 *again*, with `Location` growing an extra `/q?` segment on every hop (`.../q?country=Spain`, then `.../q?country=Spain/q?`, then `.../q?/q?`, ...) until curl's redirect limit or a `429` (rate limit from all the extra hops) killed the chain. This is the external API's own quirk, not something fixable by cleverer response rewriting from our side.
**Actual fix**: never let the redirect happen at all — confirmed `GET` straight to `.../cities/q?country=X` (through our own gateway) returns `200` cleanly with no further redirect. `charts/all/workshop-kuadrant-apis/templates/envoyfilter-cors-preflight.yaml`'s `workshop-apis-gateway-restcountries-cities-rewrite` EnvoyFilter uses an `envoy_on_request` Lua filter that, for exactly `POST /countries/cities`, reads the JSON body (`request_handle:body()`), extracts `country`, and rewrites the request in place to `GET /countries/cities/q?country=<url-encoded value>` *before* it ever reaches the upstream — the existing `ReplacePrefixMatch` `URLRewrite` on the route then runs normally afterward and produces the correct final upstream URL, no redirect ever generated.
**Two non-obvious Envoy Lua pitfalls hit building this (both confirmed live via temporary `request_handle:logWarn()` tracing — essential technique, since Lua script errors don't show up in the HTTP response, only in the proxy's own container logs at `warning`/`error` level, and `logInfo()` calls were silently dropped entirely on this build, seemingly a no-op below the effective threshold — always start with `logWarn` when adding temporary Lua tracing, not `logInfo`)**:
1. **Filter insertion point runs BEFORE the HTTPRoute's own `URLRewrite`.** A Lua filter inserted `INSERT_BEFORE router` at the Gateway *listener* level executes before the *route-action-level* rewrite the router itself applies — the path this filter observes is still the original external `/countries/cities`, never the already-rewritten `/api/v0.1/countries/cities`. Match/rewrite on the external path and let the existing route-level `URLRewrite` still do its job afterward, rather than duplicating upstream-path knowledge in the Lua filter.
2. **`request_handle:body()` invalidates previously-held handles.** Buffering the whole request body via `body()` suspends/resumes the filter's coroutine internally; any `headers` handle obtained *before* that call becomes invalid afterward — mutating it throws a runtime `object used outside of proper scope` error (a `500`/`503` to the client, with the real cause visible only in the proxy's own logs, not the response). Always call `request_handle:headers()` again to get a *fresh* handle immediately before mutating anything, if a `body()` call happened anywhere earlier in the same function.

### Argo CD MCP token chain (do not reuse `spokeCredentials` tokens)
`spokeCredentials.clusters.*.token` (Pattern CR `extraParameters` → `acm-hub-spoke`) is for **ACM cluster import** only. Argo CD MCP uses a separate chain:
1. `ai-agent` local user + scoped RBAC on each cluster's singleton `ArgoCD/vp-gitops` CR — **hub**: `charts/all/openshift-gitops` (`argocdLocalUser.enabled=true`); **east/west**: `charts/all/argocd-local-users` (wave 0). Never deploy both charts' RBAC-owning template on the *same* cluster (see singleton-ownership pitfall below).
2. `argocd-mcp-spoke-export` (spokes, wave 1) — PostSync Job writes token + URL to ConfigMap `argocd-mcp-hub-export`
3. `argocd-mcp` (hub, wave 3) — hub PostSync Job patches Vault `secret/hub/argocd-mcp-tokens`; spoke sync Job reads spoke ConfigMaps via **ManagedClusterView**; ESO builds `argocd-mcp-hub-creds` + `token-registry.json`
4. MCP endpoint: `http://argocd-mcp.argocd-mcp.svc.cluster.local:3000/mcp` (image `ghcr.io/argoproj-labs/mcp-for-argocd:v0.8.0`)

**Sync pitfall**: do not sync `argocd-local-users`/`openshift-gitops` with `--force` when `ServerSideApply=true` is set — Argo CD rejects `--force` + `--server-side` together. **Showroom**: modules 09/10 document native MaaS and MCP; terminal helpers `maas-native-status` and `argocd-mcp-status` in `charts/all/showroom/templates/showroom.yaml`.

### Singleton-ownership incident: `openshift-gitops` chart and `argocd-local-users` both patching `ArgoCD/vp-gitops` on the hub
Discovered live on the hub (Jul 2026): both `charts/all/openshift-gitops` (wave 0) and `charts/all/argocd-local-users` (also wave 0, deployed on hub too at the time) declared `spec.rbac` on the *same* `ArgoCD/vp-gitops` CR via `ServerSideApply=true`. Argo CD's SSA implementation appears to reuse a shared field-manager identity across different Applications applying the same object, so whichever Application's sync ran most recently silently won or partially truncated the other's fields — `spec.localUsers` disappeared entirely and `spec.rbac.policy` lost its last lines, **with the sync operation reporting `Succeeded`/no error**. This is the exact same failure class as the documented Kuadrant/Authorino/Limitador and Kiali singleton pitfalls, just for the ArgoCD CR instead of a CRD-managed singleton. **Fix applied**: consolidated hub ownership into `openshift-gitops` chart (`argocdLocalUser.enabled` flag adds the ai-agent `localUsers` entry + `rbac.policy` lines conditionally); removed the `argocd-local-users` Application from `values-hub.yaml` (kept for east/west, where no competing chart exists). **Detection technique**: if a chart's SSA-applied CR fields keep vanishing/truncating despite `status.operationState.phase: Succeeded` and no visible errors, grep the whole repo for every other chart/template that touches the same `kind`+`name`+`namespace` — do not assume a clean sync means the live object matches your manifest; always `oc get <kind> <name> -o yaml` and diff against `helm template` output.

### Centralize repeated overrides via `values-global.yaml` (recommended)
Duplicate `userCount: "30"` and `maas.endpoint` across many hub application overrides. Prefer adding to `values-global.yaml`:
```yaml
global:
  workshop:
    userCount: 30
  maas:
    externalHost: maas-rhdp.apps.maas.redhatworkshops.io
    native:
      enabled: true
  argocdMcp:
    enabled: true
    vaultPath: secret/hub/argocd-mcp-tokens
```
Then reference `{{ .Values.global.workshop.userCount }}` in chart defaults instead of repeating overrides in seven applications.

### Opt-in GPU hub overlay (`values-hub-gpu.yaml`) — never loaded by default
`values-hub-gpu.yaml` at the repo root is an **overlay**, not a replacement for `values-hub.yaml` — the default CPU-only install (used for the tagged/released version of this pattern) is completely unaffected unless someone explicitly passes it as an extra `-f`/`EXTRA_HELM_OPTS` file. It layers in: `openshift-nfd` + `nvidia-gpu-operator` namespaces/subscriptions, and a `gpu.enabled: true` override for `openshift-ai-hub` (rendered by `charts/all/openshift-ai-hub/templates/gpu-vllm-models.yaml`, gated behind `{{- if $gpu.enabled }}`) that deploys real GPU-backed vLLM `ServingRuntime`/`InferenceService` pairs (Red Hat AI FP8-quantized models from `huggingface.co/RedHatAI`) into a separate `gpu-models` namespace. **Helm merge caveat that matters here**: Helm deep-merges maps across `-f` files but replaces **lists** wholesale — `values-hub-gpu.yaml`'s `openshift-ai-hub` application `overrides:` list must repeat every entry from `values-hub.yaml`'s own `overrides:` for that same application (plus the new `gpu.enabled` one), or the overlay silently drops fields the base file sets. Needs a GPU worker node (e.g. AWS `g6.12xlarge`, 4x L4) — see `docs/content/patterns/ia-computer-vision/cluster-sizing.adoc`.

### `acm-argocd-openapi-fix` hook only restarts the controller when it actually fixed something
`charts/all/openshift-gitops/templates/acm-argocd-openapi-fix.yaml`'s PostSync `Job`/`CronJob` mitigates a known ACM `ocm-proxyserver` OpenAPI bug that makes hub Applications show `Sync=Unknown`. Both the one-shot Job and the `*/15 * * * *` CronJob now check whether `ocm-proxyserver` actually needed scaling down or an `APIService` actually needed deleting **before** restarting the `<argoNs>-application-controller` StatefulSet — restarting unconditionally on every run used to add its own churn on top of the `patterns-operator` reconcile-loop bug documented below (each restart interrupts every Application sync that happened to be mid-flight at that moment, not just this hook's own target). If you ever touch this file again, preserve the `changed=true`-gated restart — do not go back to an unconditional `oc rollout restart`.

## Lessons learned from a full hub-only + GPU + pre-installed-operators replicability audit (Jul 5-6, 2026)

Triggered by a request to verify the entire hub-only overlay stack (see the section above) is replicable from a fresh Pattern CR install, not just working on the currently-iterated-on live cluster. Found and fixed three distinct, repo-wide bug classes — all three were **live and observed**, not theoretical.

### Sprig `default true` on a boolean silently no-ops an explicit `false` override — 17 more instances found repo-wide
Already known for one case (`spoke-token-sync.yaml`'s `.enabled` — see the numeric-zero variant of this same root cause a few entries below). A full `grep -rn '| default true' charts/` swept up **17 more** occurrences across `hub-interconnect`, `workshop-kuadrant-apis`, `openshift-gitops`, `rhbk-iam`, `developer-hub` (6 templates), `acs-init-bundle-sync`, `openshift-ai-hub`, `workshop-registration`, `neuroface-gateway`, and `argocd-local-users` — every single one gating a `.enabled`/`useVault`/`apiKey`/`autoRenewToken`/`adminPermissionsEnabled` flag that ALSO already defaults to `true` in that chart's own `values.yaml` (making the `| default true` purely redundant *and* actively dangerous). **Fix pattern**: since the chart's own `values.yaml` already provides the `true` default, just delete the `| default true` — do not replace it with a "safer" default idiom, the chart default already covers the missing-key case. **Verification technique**: `helm template <chart> --set <flag>.enabled=false` for every fixed condition, confirming the gated resource is actually absent (not just that the chart still renders).

### Helm replaces an Application's `overrides:` list wholesale across MULTIPLE overlay files, not just base-vs-one-overlay
The known "list replaced wholesale" caveat (documented for `values-hub-gpu.yaml` vs `values-hub.yaml`) also bites when **three or more** `values-hub-*.yaml` overlays are composed together and more than one of them overrides the *same* application. `values-hub-rhpds.yaml` added `ssoHostPrefix`-only override blocks for `rhbk-iam`, `workshop-registration`, and `devspaces` — each of which ALSO already had a `userCount`/`registration.maxUsers` override from `values-hub-single-node.yaml` (which loads earlier). Because `values-hub-rhpds.yaml`'s override list didn't repeat those fields, they were silently dropped for the full documented stack. **Confirmed live**: `rhbk-iam`'s `userCount` reverted to its chart default of 30, leaving `ExternalSecret`s for `user6`..`user30` permanently `Degraded` (`could not get secret data from provider`, since `vault-secrets-bootstrap` only ever seeds 5 users in this stack). **Detection technique**: for a documented multi-overlay stack, script a comparison of every application's override *names* across every file in the stack — flag any name present in an earlier file but absent from a later file that ALSO overrides that same application (see the one-off Python script used this session, or add it as a repo Makefile target if this recurs again). **After fixing a live override drop**: the stale, no-longer-desired resources (e.g. `user6..30` ExternalSecrets) do NOT get auto-pruned — this pattern's `syncPolicy.automated` has no `prune: true` by design (Validated Patterns default) — so a manual `oc delete` of the orphaned resources plus a hard-refresh is required to see the Application actually go green, even though the *fix itself* (the values file) is already correct at that point.

### `platform-users` hardcoded `stackrox` into its namespace-view RoleBinding list — breaks by default, everywhere
ACS/RHACS is commented out / disabled by default in `values-hub.yaml`, `values-east.yaml`, and `values-west.yaml` alike ("ACS disabled by default to save resources"), yet `charts/all/platform-users/values.yaml`'s `viewNamespacesHub`/`viewNamespacesSpoke` lists both unconditionally included `stackrox`. Since that namespace never gets created, the `RoleBinding` targeting it is rejected by the API server, and `platform-users` stays permanently `OutOfSync`/`Missing` on **every default install of this pattern**, hub or spoke — not just the hub-only overlay stack. **Fix**: added `acsEnabled` (default `false`, matching the pattern-wide default) to `platform-users/values.yaml`; `workshop-namespace-view.yaml` only appends `"stackrox"` to the namespace list when `acsEnabled: true`. **General lesson**: any chart-local hardcoded namespace/resource reference to an *optional, disabled-by-default* component needs a values flag gating it — grep any chart for the literal names of every commented-out subscription in `values-hub.yaml` (`stackrox`, `quay`, etc.) to catch more of this class before it ships.

### Live-cluster validation technique for "would a fresh install actually work" questions
`helm template hub-only validatedpatterns/clustergroup --version <clusterGroupChartVersion from values-global.yaml> -f values-hub.yaml -f values-hub-gpu.yaml -f values-hub-single-node.yaml -f values-hub-rhpds.yaml -f values-hub-only.yaml --set global.repoURL=... --set global.pattern=... --set global.clusterDomain=... --set clusterGroup.name=hub` (pull the real chart via `helm repo add validatedpatterns https://charts.validatedpatterns.io`) renders the **exact** manifest the Pattern operator would produce for a from-scratch install with that `extraValueFiles` stack — including every generated `Application`'s `spec.source.helm.parameters`. This is the authoritative way to confirm an override actually reaches a given application (vs. inspecting each values file by eye, which is exactly what missed the override-wholesale-replace bug above in the first place). Diff the resulting `Application` count/names and each one's `helm.parameters` against what you expect, rather than trusting the values files' apparent intent.

## Lessons learned from a full-architecture operational review (Jul 6, 2026)

Triggered by a request to verify the entire architecture is operational after the replicability audit above. Found and fixed two more real, live-observed bugs, both PostSync hook Jobs stuck in silent infinite-retry loops that a routine `oc get applications` health check does NOT surface (`status.health`/`status.sync` can show `Healthy`/`Synced` while `status.operationState` is actually still `Running`/stuck retrying, or terminally `Failed`, from an operation that started hours earlier) -- always cross-check `operationState.phase` + `startedAt` across every Application, not just the top-level sync/health columns, when asked to verify the whole architecture is healthy.

### `developer-hub-sync-apiproduct-openapi` PostSync hook ran a stale, pre-fix script for hours after the fix was already committed
The live Job object still executed `import json, os, subprocess, tempfile, yaml` (crashing with `ModuleNotFoundError: No module named 'yaml'`) even though the file in Git, and the exact revision the Application's `.status.sync.revision` claimed to be synced to, had already been fixed to use only `json`. Root cause: the sync **operation itself** was stuck retrying since a `startedAt` timestamp from hours earlier, using whatever manifest was cached/rendered at that time -- a plain `argocd.argoproj.io/refresh=hard` annotation plus a new `operation` patch is not sufficient to interrupt an *already-running* operation (the patch silently no-ops if one is in flight). **Fix**: `oc exec deploy/<argocd-server> -n <ns> -- sh -c 'export ARGOCD_OPTS=--core; argocd app terminate-op <app>'` to actually kill the stuck operation, THEN hard-refresh + resync. For an immediate live unblock without waiting on ArgoCD's own catch-up, render the exact Job manifest with `helm template <chart> --set <every param from oc get application ... jsonpath='{.spec.source.helm.parameters}'>` (substituting the literal `$ARGOCD_APP_NAMESPACE` placeholder with the real destination namespace) and `oc apply -f -` it directly after deleting the stale Job.

### `vault-secrets-bootstrap` PostSync hook: three compounding bugs, one per debugging round
This chart's Vault-seeding Job had never actually been exercised against this cluster's real Vault TLS/auth configuration before (its `secret_exists()` short-circuit meant it always skipped real work once the very first secret existed, seeded on a much earlier, differently-configured cluster state) -- when a routine full-architecture check finally forced a fresh run, it failed three different ways in sequence, each only visible after fixing the previous one:
1. **`http://` against a TLS-only Vault listener**: same root cause as the already-documented "Vault used HTTPS but jobs used HTTP" class of bug (see the PPE/model-seed incidents below) -- the Service port is *named* "http" (8200) but Vault's actual listener config has TLS enabled regardless of the port name. `curl -f` treats a plain-HTTP-to-HTTPS-server rejection identically to "not up yet", so the job's own `wait_vault()` retried all 60 attempts and reported a misleading "Vault not ready" even though Vault was healthy.
2. **`microdnf install -y curl jq` does not reliably work on `ubi9/ubi-minimal`** in this environment (no working repo config without an entitled subscription) -- the original script's `|| true` on that line silently swallowed the install failure, so the job only surfaced it later as `jq: command not found`. Fix: switch the image to `registry.redhat.io/ubi9/python-311:latest` (curl preinstalled) and rewrite the script in Python, using `json` instead of `jq` -- the same image/approach already used successfully by `spoke-neuroface-cv`'s and `hub-interconnect`'s own `job-model-seed.yaml`.
3. **Kubernetes-auth login to Vault fails outright**: `vault read auth/kubernetes/config` on this cluster returns "No value found" -- there is no `kubernetes/` auth mount or `secret-manager` role configured at all (only a read-only `hub/` mount used by External Secrets Operator). Any job attempting `POST /v1/auth/kubernetes/login` here will always fail regardless of the URL scheme. Fix: authenticate with the **root token from `imperative/vaultkeys`** instead (the standard Validated Patterns location, written by this pattern's own Vault bootstrap on every install) -- fetch it via the Kubernetes API using the pod's own ServiceAccount token (`https://kubernetes.default.svc/api/v1/namespaces/imperative/secrets/vaultkeys`, decode `data.vault_data_json` from base64, parse the JSON, read `root_token`), exactly as `job-model-seed.yaml` already does. Needs a `Role`/`RoleBinding` in the `imperative` namespace granting the job's own ServiceAccount `get` on that one named secret.

**General lesson**: any NEW (or newly re-exercised) job that talks to this cluster's Vault directly (not via ExternalSecrets/ESO, which already has its own working auth) should be written from the start using the `imperative/vaultkeys` root-token pattern over `https://`, matching `job-model-seed.yaml` -- do not assume Kubernetes-auth is configured, and do not assume `curl`/`jq` are preinstalled or installable at runtime on `ubi-minimal`-family images without testing on this specific cluster first.

### `kuadrant-operator-restart-hook` burned 6 minutes on every sync due to a missing RBAC rule for the resource it was polling
The hook's readiness-wait loop (`oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='...status.conditions...'`) always came back empty even though the `Kuadrant` CR genuinely was `Ready` the whole time -- its `ClusterRole` granted `apps/deployments` and `gateway.networking.k8s.io/gatewayclasses` but never `kuadrant.io/kuadrants`. Every `oc get` inside the loop silently failed `Forbidden` (swallowed by `|| true`), so `$ready` never became `"True"` and the loop always exhausted its full 36 x 10s budget (6 minutes) before giving up with a soft `WARN`/`exit 0` -- not a hard failure, so `oc get applications` never showed anything worse than a slow, "still Running" `operationState` for 6 minutes on **every single sync** of this Application. **Detection technique**: `oc auth can-i get <group> --as=system:serviceaccount:<ns>:<sa-name> -n <target-ns>` for any RBAC-scoped readiness/wait loop in a hook Job, checking every resource type the script's `oc get`/`oc wait` commands actually touch against the `ClusterRole`/`Role` rules granted to that specific `ServiceAccount` -- do not assume a `|| true`-guarded check that "looks like a normal wait loop" is actually succeeding just because the Job eventually exits 0. **Fix**: RBAC changes to a live `ClusterRole` take effect immediately without restarting the already-running pod (permissions are checked per-API-call) -- `oc patch clusterrole <name> --type json -p '[{"op":"add","path":"/rules/-","value":{...}}]'` unblocks a currently-stuck loop without needing to kill/recreate the Job first.

## Key constraints

- Developer Hub: only `ai-computer-vision` software template
- TSSC (RHTAS, RHTPA): optional, commented out in values-hub.yaml
- Service Mesh: VP `servicemesh` chart with `profile: ambient` on hub and spokes
- ArgoCD: hub needs 12Gi controller memory via `openshift-gitops` chart
- Community plugins: disable in `configmap-dynamic-plugins-rhdh.yaml` any `backstage-community-plugin-*` not in the RHDH image
- API catalog: `workshop-kuadrant-apis.yaml` and `public-apis.yaml` use `__SPEC__` placeholders injected by `catalog-kuadrant-apis.yaml` and `catalog-public-apis.yaml` templates

## Day-1 automation checklist (fresh install)

Everything below happens automatically via sync waves and PostSync jobs. The only manual input is `spoke-credentials` tokens.

1. **Wave 0**: `platform-users` creates `acm-import` SA with `cluster-admin` on spokes
2. **Wave 2**: Vault initializes, ESO creates `ClusterSecretStore vault-backend`, secrets auto-generated
3. **Wave 3**: GitLab deploys with correct external URL (`gitlab.apps.<domain>` via helper)
4. **Wave 4**: Developer Hub deploys with `GITLAB_TOKEN=placeholder`
   - **PostSync**: `gitlab-token-setup` job creates GitLab root PAT via rails, patches Secret + Vault, restarts RHDH
5. **Wave 5**: Service Mesh (Istio ambient), Skupper VAN, Showroom
6. **Wave 6**: Gateway HA (2 replicas via ConfigMap parametersRef), ACM hub-spoke auto-import
7. **Wave 4 (ongoing)**: ApplicationSet `user-neuroface-apps` discovers `neuroface-*` GitLab repos, deploys to spokes

### Post-install verification
```bash
# GitLab PAT working
TOKEN=$(oc get secret developer-hub-oidc-auth -n developer-hub -o jsonpath='{.data.GITLAB_TOKEN}' | base64 -d)
curl -skS -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.apps.$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')/api/v4/user"
# Expected: 200

# Clone URL correct (not gitlab-gitlab.apps)
curl -skS -X POST -H "PRIVATE-TOKEN: $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"test","namespace_id":69}' \
  "https://gitlab.apps.$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')/api/v4/projects" \
  | grep -o '"http_url_to_repo":"[^"]*"'
# Expected: "http_url_to_repo":"https://gitlab.apps.<domain>/ws-workshop/test.git"
# (delete test project after)

# Spokes registered
oc get gitopscluster hub-spoke-gitops -n openshift-gitops -o jsonpath='{.status.conditions[?(@.type=="PlacementResolved")].message}'
# Expected: Successfully resolved 2 managed clusters from placement
```

## Reference plan

See [PLAN.md](../../PLAN.md) for the full implementation plan.
