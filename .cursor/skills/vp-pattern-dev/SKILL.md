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
**Fix**: Override `keycloak.hostname: sso` in `values-hub.yaml` so Keycloak issues cookies on the `sso.apps.<domain>` hostname. Update console links to use `sso.<domain>` as well.

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
