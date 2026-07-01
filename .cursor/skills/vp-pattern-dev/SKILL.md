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
**Genuine remaining limitation found by this exercise**: even with the policy-level `when` exemption working (confirmed: Authorino now lets `OPTIONS` straight through), the upstream *application* itself can still break preflight -- `neuroface-cv`'s backend returns a proper `405 Method Not Allowed` for `OPTIONS /health` (unlike `neuroface-app`'s backend, which happens to answer `OPTIONS` the same as `GET`/any other method). A `405` is just as fatal to a real browser preflight as a `401`/`302` would be. Gateway API `HTTPRoute` filters can't synthesize a canned `2xx` response before the backend is reached (no "direct response" filter type in this CRD version -- see the CORS pitfall above for the full filter-type list); that would need an Istio `EnvoyFilter` (a lower-level, non-Gateway-API primitive) or an app-side fix, both out of scope for a quick policy change. Simple requests (no custom headers, so no preflight is ever triggered) still work fine regardless.

### Helm `range` rebinds `.` to the loop item -- `include "chart.helper" .` inside a range silently breaks any helper reading `.Values`
`workshop-kuadrant-apis/templates/routes.yaml` calls a shared corsFilter helper from inside `{{- range $name, $api := .Values.apis }}`. Using `.` (instead of `$`) for the `include` context there panics with `nil pointer evaluating interface {}.global`, because inside the range body `.` is rebound to the current map value (`$api`, e.g. `{enabled: true, host: ...}`), not the chart root -- so `.Values` inside the helper resolves against `$api.Values` (undefined) instead of the real root `.Values`. Always pass `$` (the root context, captured automatically by Helm/Go templates) to any `include`/`template` call made from inside a `range`, `with`, or any other block that rebinds `.`.

### Backstage's `POST /api/notifications` cannot be called from a scaffolder template step -- ever
`http:backstage:request` (roadiehq) can only carry `user`-derived credentials (either the initiator's plugin-request-token, or the raw `backstageToken` via `useBackstageToken: true` -- both are `user` principals). `@backstage/plugin-notifications-backend`'s create-notification route (`POST /` and `POST /notifications`) requires `allow: ["service"]` (confirmed in `.../plugin-notifications-backend/dist/service/router.cjs.js`), rejecting every `user`-principal call with `403 NotAllowedError: This endpoint does not allow 'user' credentials`. This is not fixable via proxy/header config (unlike the Authorization-forwarding pitfall above) -- it is a hardcoded `allow` list in an installed npm package. The only two ways to actually send a notification from a template are (a) show the payload directly in `spec.output.text` instead (no new dependency, works today), or (b) add `@backstage/plugin-scaffolder-backend-module-notifications` (the `notification:send` action, which runs in-process with real service credentials) as a dynamic plugin -- note this package is **not** available in RHDH's `rhdh-plugin-export-overlays` OCI registry (that repo only re-hosts *community* plugins), so it would have to be fetched straight from the public npm registry, which needs its own verification (registry egress, version compatibility with the running Backstage core version) before relying on it.

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
