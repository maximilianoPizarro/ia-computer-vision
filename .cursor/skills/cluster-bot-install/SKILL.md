---
name: cluster-bot-install
description: >-
  Provision a fresh OpenShift cluster via Cluster Bot (ci-chat-bot) sized for
  the ia-computer-vision hub-only CPU pattern, and recover from the known
  first-boot issues a cluster with NO pre-installed operators hits (cert-manager
  missing, RHBK/ESO sync-wave races, Keycloak Fine-Grained Admin Permissions
  locking out the backstage realm, Kuadrant Gateway API dependency race). Also
  covers OpenTLC/catalog sandboxes that already have cert-manager (TooManyOperatorGroups
  without values-hub-rhpds.yaml), Kuadrant WASM fail-closed 503s, FGAP on realm
  cv vs backstage, and hub-local HTTPRoute ExternalName 503s. Use when asked to
  launch a Cluster Bot cluster for this pattern, or when diagnosing SSO 503s,
  Developer Hub "unauthorized_client"/"Realm does not exist" errors, GitLab stuck
  in "Preparing" (cert-manager missing OR chart 10.x missing external
  Postgres/Redis/MinIO), invalid Kuadrant AuthPolicy, or missing API
  Products/Swagger definitions right after a fresh install.
---

# Cluster Bot install -- ia-computer-vision hub-only CPU

## 1. Launch command (verified sizing)

```
workflow-launch openshift-e2e-aws 4.20 "COMPUTE_NODE_TYPE=m6a.4xlarge","CONTROL_PLANE_INSTANCE_TYPE=m6a.2xlarge","COMPUTE_NODE_REPLICAS=4"
```

**Do not pass `--lease` to `workflow-launch`.** It is not a bot flag — Cluster Bot
treats it as a workflow env var and the job fails in ~10s with:
`parameter "--lease 8h \"COMPUTE_NODE_TYPE" is overridden ... but not declared in any step`
(putting it after the params corrupts `replicas` instead; either way the cluster is never created).

Default cluster lifetime from `workflow-launch` is **~3 hours** after the cluster is ready
(`maxAge` in ci-chat-bot). For an 8h cluster use `mce create <version> 8h <platform>` if
you have MCE access, or plan the hub-only install + demo within the default window.

- Parameter names come from the `openshift-e2e-aws` workflow (`ipi-conf-aws` step) --
  `COMPUTE_TYPE`/`CONTROLPLANE_TYPE` **do not exist** and fail ci-operator config
  resolution in ~10s (`parameter "X" is overridden ... but not declared in any step`).
  Use `COMPUTE_NODE_TYPE`, `CONTROL_PLANE_INSTANCE_TYPE`, `COMPUTE_NODE_REPLICAS`.
- Prefer a specific `4.20.x` (e.g. `4.20.28`, Accepted on
  https://amd64.ocp.releases.ci.openshift.org/) over bare `4.20` if the latest
  nightly is `Rejected` -- check with `lookup 4.20 amd64` in Cluster Bot first.
- Confirmed working sizing: 3x control plane (8 vCPU/32Gi, `m6a.2xlarge`) +
  4x workers (16 vCPU/64Gi, `m6a.4xlarge`). CPU usage stayed 6-29% across
  workers with the full hub-only stack (GitLab, Developer Hub, Keycloak,
  OpenShift AI, Kuadrant/Kiali/ServiceMesh, Kafka/Strimzi) -- do not go below
  3 workers `m6a.4xlarge`; `m6a.2xlarge` workers hit ~98% CPU requests.
- A job failing in ~10s = bad parameter name, not a real provisioning failure.
  A job running 30-60+ min = real install in progress.

## 2. Post-provision sequence

1. `auth` in Cluster Bot (or wait for the bot's DM) to get the kubeconfig.
2. Install the **Validated Patterns Operator** from OperatorHub.
3. Apply the Pattern CR:
   ```bash
   oc apply -f https://raw.githubusercontent.com/maximilianoPizarro/ia-computer-vision/main/examples/pattern-cr/hub-only-cpu.yaml
   ```
4. Expect ~1-2h for ArgoCD to reach Healthy/Synced across ~26 apps. Work
   through section 3 below **proactively** -- these are not edge cases, they
   reproduced on every from-scratch Cluster Bot cluster tested.

## 3. Known first-boot issues on a clean cluster (no pre-installed operators)

These do NOT happen on RHPDS/sandbox clusters that come with operators
pre-installed -- they are specific to truly empty clusters, which is exactly
what Cluster Bot gives you. **As of the fixes below, all of these are now
self-healing from `oc apply -f hub-only-cpu.yaml` alone -- no manual
intervention should be needed on a fresh install.** Sections are kept for
diagnosis if something still slips through.

### 3.1 cert-manager missing -> GitLab stuck in "Preparing" forever

**Symptom:** `oc get gitlab gitlab -n gitlab-system` stays `Preparing`; only
gitaly/postgres/redis/minio pods exist, no webservice/sidekiq/registry/kas.
`gitlab-controller-manager` logs loop on:
```
no matches for kind "Issuer" in version "cert-manager.io/v1"
```

**Cause:** the GitLab Operator needs cert-manager for its OWN webhook cert
regardless of `installCertmanager: false` / `certmanager.install: false` in
the GitLab CR (those only control the GitLab *chart's* ingress certs). On
older pattern revisions the `cert-manager` subscription was commented out;
current `values-hub.yaml` enables it by default.

**Automated fix (already in the pattern):** `values-hub.yaml` includes
`cert-manager-operator` as a normal namespace + subscription (installed by
OLM early, in parallel with every other operator, well before
`gitlab-operator`'s sync-wave 3). Toggle with the clustergroup native flag:

```yaml
clusterGroup:
  subscriptions:
    cert-manager:
      disabled: true   # skip install (cluster already has it)
  namespaces:
    cert-manager-operator:
      operatorGroup: false   # avoid TooManyOperatorGroups
```

`values-hub-rhpds.yaml` sets both for Scenario D / pre-provisioned sandboxes.
Default (no overlay) keeps cert-manager enabled for Cluster Bot / clean clusters.
No manual step needed on a fresh install -- GitLab's own controller retry
loop (backoff up to ~16 min) would eventually self-heal even in the unlikely
case of a residual race, but with cert-manager present from the start it
should just work on the first pass.

**OpenTLC / catalog CPU sandboxes (not Scenario D):** the catalog already
created `OperatorGroup/cert-manager-operator-og`. Adding the pattern's
`cert-manager-operator-operator-group` fails the CSV with
`TooManyOperatorGroups`. Use Scenario A2:

```
extraValueFiles:
  - /values-hub-only.yaml
  - /values-hub-preinstalled-operators.yaml
```

File: `examples/pattern-cr/hub-only-cpu-preinstalled.yaml`. That overlay
ONLY sets `clusterGroup.namespaces.cert-manager-operator.operatorGroup: false`.
**Do not** add `values-hub-rhpds.yaml` on OpenTLC CPU -- it changes
`ssoHostPrefix` to `rhdh-sso` and assumes RHOAI is pre-installed.

Live recovery if the second OG already exists: delete
`cert-manager-operator-operator-group`, keep the catalog OG, recreate the
subscription if the CSV stays Failed.

**Manual fallback if you hit an already-broken GitLab install** (e.g. an
older cluster missing this fix): install `openshift-cert-manager-operator`
(channel `stable-v1`) in its own `cert-manager-operator` namespace/
OperatorGroup, wait ~60s, then `oc delete pod -n gitlab-system -l
app.kubernetes.io/name=gitlab-operator` to force an immediate re-reconcile
instead of waiting out the backoff.

### 3.1b GitLab chart 10.x "bundled MinIO removed" -> Preparing forever

**Symptom:** `oc get gitlab gitlab -n gitlab-system` stays `Preparing` with
`Initialized=False` / "There is a configuration error". Operator logs:
```
REMOVALS:
global.minio:
    The bundled MinIO chart has been removed...
```
No webservice pods; route returns 503; `gitlab-minio-secret` / `gitlab-minio-svc`
missing → `ppe-model-seed` and YOLO Init stay blocked.

**Cause:** GitLab Operator 3.2.x only admits Helm chart **10.x**. Chart 10
removed bundled PostgreSQL, Redis, and MinIO. Values that still set
`global.minio.enabled` fail template render (NOTES.txt hard-fail).

**Automated fix (v1.8.5+ / v1.8.6):**
- OLM: `cloudnative-pg` (certified) + `redis-operator` (community) from
  `values-hub.yaml`
- Chart `gitlab-operator`: CNPG `Cluster/gitlab-rails-db`, Redis CR
  (includes required `redisExporter.image`), chart-managed MinIO
  (`gitlab-minio-svc` + `gitlab-minio-secret`), Job that creates GitLab S3
  buckets + `gitlab-object-storage` / `gitlab-registry-storage` /
  `gitlab-object-storage-s3cmd`, GitLab CR with external `psql`/`redis`/
  `object_store` + toolbox backup objectStorage (no `global.minio`)

**Verify:**
```bash
oc get csv -n cnpg-system | grep cloudnative
oc get csv -n redis-operator | grep redis
oc get cluster.postgresql.cnpg.io -n gitlab-system
oc get redis -n gitlab-system
oc get sts,svc,secret -n gitlab-system | grep -E 'minio|object-storage|registry-storage'
oc get gitlab gitlab -n gitlab-system   # expect Running / Available
```

Do **not** use MinIO AIStor ObjectStore for Cluster Bot workshops — it is
commercial (SUBNET) and will not zero-touch install.

Do **not** enable `values-hub-odf-datagrid.yaml` on Cluster Bot. That overlay
expects an existing ODF StorageCluster/MCG and Red Hat Data Grid (RESP for
GitLab is experimental). Keep chart-managed MinIO + Opstree Redis here.

### 3.1c MinIO SCC / Redis Operator RBAC (GitLab external deps stuck)

**Symptom:** `gitlab-operator` Progressing forever; `StatefulSet/gitlab-minio`
never creates a pod (`fsGroup: 1000` / `restricted-v3` hostUsers); Redis
Operator pod CrashLoopBackOff with `cannot list resource "redisreplications"`.

**Cause:** chart MinIO pinned UID/fsGroup 1000 (rejected by OpenShift
restricted SCCs). Opstree Redis Operator CSV RBAC covers Redis/RedisCluster
but the controller also watches RedisReplication/RedisSentinel.

**Pattern fix:** MinIO uses SA `gitlab-minio` + SCC `anyuid` (UID 1000,
sync-wave 0 before the StatefulSet); early Argo app `redis-operator-rbac`
(syncWave 1) adds the missing ClusterRoleBinding before the operator CSV
settles; Redis OperatorGroup targets only `gitlab-system`.

### 3.1d gitlab-object-storage-setup Init CrashLoop (wait-minio)

**Symptom:** `gitlab-object-storage-setup` stuck `Init:0/2` restarting;
`wait-minio` exits 1 after ~7.5m while `gitlab-minio-0` is already Running.

**Cause:** wait script used `oc get endpoints` but the Job Role only allowed
`pods`/`services` — forbidden reads were swallowed and the loop timed out.

**Pattern fix:** Role grants `endpoints` + `endpointslices`; wait checks
StatefulSet `readyReplicas` (and Ready pod) instead of Endpoints only.
`create-buckets` sets `HOME`/`MC_CONFIG_DIR` under `/tmp` so `mc` works
under OpenShift restricted SCC (`mkdir /.mc` is denied).

### 3.1e GitLab chart 10.2 Gateway API / EnvoyProxy -> Preparing forever

**Symptom:** `oc get gitlab gitlab -n gitlab-system` stays `Preparing`;
MinIO/Redis/Postgres are Ready but no gitaly/webservice/sidekiq pods.
Operator logs loop on:
```
no matches for kind "EnvoyProxy" in version "gateway.envoyproxy.io/v1alpha1"
```

**Cause:** GitLab chart **10.2+** defaults `global.gatewayApi.enabled` and
`installEnvoy: true`. The Operator then reconciles Envoy Gateway CRs. Cluster
Bot / this pattern expose GitLab via OpenShift Routes (+ optional Istio
`Gateway` in `gitlab-gateway.yaml`) and do **not** install Envoy Gateway.

**Pattern fix:** `gitlab-cr.yaml` sets `global.gatewayApi.enabled: false`,
`installEnvoy: false`, and `global.ingress.enabled: true` (chart 10.2 also
defaults ingress off when Gateway API is the default path).

**Manual fallback on an already-broken CR:**
```bash
oc patch gitlab gitlab -n gitlab-system --type merge -p '{
  "spec":{"chart":{"values":{"global":{
    "gatewayApi":{"enabled":false,"installEnvoy":false,"configureCertmanager":false},
    "ingress":{"enabled":true}
  }}}}
}'
```

### 3.1f gitlab-registry CrashLoop — flat YAML in registry-storage secret

**Symptom:** `gitlab-registry-*` CrashLoopBackOff with:
```
configuration error: ... cannot unmarshal !!map into string
```

**Cause:** `gitlab-object-storage-setup` used `sed` to strip all leading
spaces from the generated `registry-storage` YAML, flattening nested `s3:`
keys so the Registry config template produced invalid YAML.

**Pattern fix:** write nested registry config with `printf` (preserve
indent). Object-store / s3cmd stay flat and still use the sed trim.

### 3.1g gitlab-migrations BackoffLimitExceeded -> CR stuck Preparing, UI 503

**Symptom:** `oc get gitlab gitlab -n gitlab-system` stays `Preparing`;
`gitlab-migrations-*` Job `Failed` / pod CrashLoop then deleted; no
`gitlab-webservice-default` or `sidekiq` Deployments. Route returns 503.

**Cause:** GitLab chart default migrations request is **200Mi**. The first
Rails migrate for 18/19 exceeds that and the Job hits `BackoffLimitExceeded`
before webservice is created. Postgres/Redis/MinIO can all be Ready.

**Pattern fix:** `gitlab-cr.yaml` sets `gitlab.migrations.resources` to 1Gi
request / 2Gi limit.

**Manual recovery on an already-failed Job** (schema may still be empty):

```bash
# If toolbox can migrate, finish schema then delete the failed Job so the
# operator recreates it (noop migrate) and starts webservice:
oc exec -n gitlab-system deploy/gitlab-toolbox -- gitlab-rake db:migrate
oc delete job -n gitlab-system -l app=migrations
# wait for gitlab-webservice-default; curl https://gitlab.<domain>/ → 302
```

### 3.2 SSO HTTP 503 -> Developer Hub OIDC 500 "expected 200 OK, got 503"

**Symptom:** `curl https://sso.<domain>/` returns 503; Developer Hub login
shows `OPError: expected 200 OK, got 503 Service Unavailable`.

**Cause (two common races):**

1. **ESO webhook race:** `rhbk` ExternalSecrets (`postgresql-db`,
   `keycloak-admin-user`) sync before the ESO validating webhook has
   endpoints → admission fails, PostgreSQL never starts, Keycloak has no DB.
2. **Keycloak CRD race (Cluster Bot first boot):** first `rhbk` sync runs
   before `keycloaks.k8s.keycloak.org` exists → Argo marks the *entire*
   sync invalid (`could not find k8s.keycloak.org/Keycloak`) and leaves
   StatefulSet/Services/Ingress/Keycloak CR **Missing** even after the CRD
   appears. Secrets may already exist via ESO fallback while SSO stays 503.

**Pattern fix:** `rhbk` syncs at wave 4 (after `vault-secrets-bootstrap`
wave 3), `rhbk-iam` at wave 5, `developer-hub` at wave 6.
`rhbk-eso-readiness` waits for the ESO webhook, applies fallback
ExternalSecrets + Keycloak CR (needs ClusterRole get on
`ingresses.config.openshift.io`, Keycloak CRD, and Routes), clears a stuck
`/operation`, and hard-refreshes `rhbk` when `StatefulSet/postgresql-db` is
still Missing. `rhbk` also has `ignoreDifferences` on `ExternalSecret`
`.status`.

**If it still races on a given cluster:**
```bash
oc get pods -n external-secrets   # confirm webhook pod is Running
oc patch application rhbk -n vp-gitops --type json -p '[{"op":"remove","path":"/operation"}]'
oc annotate application rhbk -n vp-gitops argocd.argoproj.io/refresh=hard --overwrite
# If postgresql-db-0 is stuck CreateContainerConfigError from the failed run:
oc scale statefulset postgresql-db -n keycloak-system --replicas=0
oc delete pvc data-postgresql-db-0 -n keycloak-system
oc scale statefulset postgresql-db -n keycloak-system --replicas=1
```

**Residual risk:** if the first `rhbk` sync fails admission on the
ExternalSecrets and Argo then blocks forever on `StatefulSet/postgresql-db`
health, a hard refresh alone may not re-apply Missing resources. Confirm with
`oc get externalsecret -n keycloak-system postgresql-db` — if NotFound after
wave 4, apply from the rhbk chart or clear the stuck operation and sync again.
The readiness Job now also clears a stuck `/operation`, waits for the
bootstrap secrets, and can delete a stuck `postgresql-db` pod once secrets
exist (needs endpoints get in `external-secrets` + pods delete in
`keycloak-system`).

**Also fixed (wrong Helm override key):** `keycloak.hostname: sso` is ignored
by the upstream `rhbk` chart. Use
`keycloak.ingress.hostname: 'sso.{{ .Values.global.localClusterDomain }}'`
(clustergroup `tpl`-expands override values). The empty default rendered
`keycloak.apps.example.com` and left Admin API / OIDC on a dead issuer until
patched by hand.

**OIDC popup still opens `keycloak.<domain>` after hostname fix:** Developer
Hub's `openid-client` caches discovery. Restart
`deploy/backstage-developer-hub` after Keycloak hostname changes. The
`developer-hub` chart also ships `Route/keycloak` as an alias so a stale
redirect does not hit OpenShift's "Application is not available" page.

### 3.3 Kuadrant AuthPolicy stuck "Invalid" (MissingDependency)

**Symptom:** AuthPolicy resources (`authpolicy-cv`, `workshop-*-auth`, etc.)
show `Invalid (Not Accepted)` in the OpenShift console. Condition message:
```
[Gateway API provider (istio / envoy gateway)] is not installed, please
restart Kuadrant Operator pod once dependency has been installed
```

**Cause:** the `rhcl` subscription (Kuadrant Operator) is OLM-installed
early, independently of Argo CD sync waves, and frequently starts before
`servicemesh-config` (sync-wave 5, installs Istio) has finished. The
operator checks for a Gateway API provider **once** at its own startup and
never rechecks on its own.

**Automated fix (already in the pattern):**
`charts/all/neuroface-gateway/templates/job-kuadrant-operator-readiness.yaml`
is a PostSync hook (sync-wave 5, same wave as `servicemesh-config`) that
waits for the `istio` GatewayClass to be `Accepted`, then runs
`oc rollout restart` on the Kuadrant + Limitador operator deployments,
waits for AuthPolicies to appear, and **re-verifies** they are `Accepted`
(up to 6 Kuadrant-only restarts). After AuthPolicies are Accepted (or on
timeout) it waits until
`http://kuadrant-operator-wasm.redhat-connectivity-link-operator.svc:8082/plugin.wasm`
returns 200 and restarts `neuroface-gateway-istio` plus
`workshop-apis-gateway-istio`. Envoy fetches WASM once at start
(fail-closed / FAIL_RELOAD): if the fetch 404s, AuthPolicy routes stay 503
(or briefly fail-open 200 with no auth) until those gateway pods restart.
`workshop-kuadrant-apis` has a secondary PostSync restart hook as a safety net.

**Bug found 2026-07-13 (ci-ln-3tzt90t):** the verify loop piped JSON into
`python3 -c` with YAML-indented source, which always hit `IndentationError`
→ `INVALID=999` → Job thrash (`OnFailure`) while AuthPolicies stayed
`MissingDependency`. Fixed by using an unindented python one-liner / jq,
`restartPolicy: Never`, Istio inject off, and deleting only
`kuadrant-operator` pods (not every `control-plane=controller-manager`).

**Manual fallback if it still races on a given cluster:**
```bash
oc delete pod -n redhat-connectivity-link-operator -l app.kubernetes.io/name=kuadrant-operator --force --grace-period=0
# or:
oc get pods -n redhat-connectivity-link-operator -o name | grep kuadrant-operator-controller | xargs oc delete -n redhat-connectivity-link-operator
# wait ~30s, then:
oc get authpolicy -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,ACCEPTED:.status.conditions[0].status,REASON:.status.conditions[0].reason
# expect Accepted=True; curl without token should 401:
DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
curl -sk -o /dev/null -w '%{http_code}\n' "https://neuroface-cv.${DOMAIN}/health"
```

### 3.4 Developer Hub OIDC "unauthorized_client (Invalid client or Invalid client credentials)"

This is the hardest one and can recur across realm re-imports if you only
delete+recreate the `KeycloakRealmImport` CR -- **deleting the CR does not
delete the realm from Keycloak's Postgres**, so a stale/locked realm persists
underneath.

**Diagnosis -- confirm it's a real secret mismatch (not a UI cache issue):**
```bash
DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
SECRET=$(oc get secret developer-hub-oidc-auth -n developer-hub -o jsonpath='{.data.OIDC_CLIENT_SECRET}' | base64 -d)
curl -sk -X POST "https://sso.${DOMAIN}/realms/backstage/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=developer-hub" -d "client_secret=${SECRET}" \
  -d "username=admin" -d "password=Welcome123!" -w "\nHTTP:%{http_code}\n"
```
`HTTP:401 unauthorized_client` confirms the secret in Vault/K8s does not
match what Keycloak has for the `developer-hub` client.

**Root causes (both seen on clean Cluster Bot installs):**

1. **Sync job race (v1.8.0):** PostSync `developer-hub-sync-backstage-realm-secrets`
   finished before `KeycloakRealmImport/backstage-realm` created clients →
   `SKIP ... (not found)` exit 0 → literal `$(OIDC_CLIENT_SECRET)` in Keycloak.
2. **FGAP lockout (ci-ln-iph27ib, even with CR `adminPermissionsEnabled: false`):**
   live realm still had Fine-Grained Admin Permissions on → Admin API
   `/clients` **403** / truncated RealmRepresentation. Sync jobs treated 403
   as “client missing” and spun for 12 minutes; secrets never repaired.

**Pattern fix (v1.8.2+):**

| Component | Behavior |
|-----------|----------|
| `keycloak-fgap-heal` (developer-hub PostSync wave 5) | Detects FGAP (403 or truncated realm) on **backstage** → deletes realm-imports → wipes `postgresql-db` PVC → hard-refreshes `rhbk-iam` + `developer-hub` → waits until Admin API is healthy. If **backstage is healthy** but **realm cv** is still 403/truncated, **restarts `keycloak-0` only** (in-memory FGAP; `adminPermissionsEnabled=false` in Postgres is not enough) and refreshes `rhbk-iam` — does **not** wipe Postgres (that takes down Developer Hub login). |
| `developer-hub-sync-backstage-realm-secrets` (wave 6) | Waits for clients; fail-fast on Admin API 403 (does not spin) |
| `rhbk-iam-sync-client-secrets` | Same wait/retry + 403 fail-fast for realm `cv` |
| Realm CRs | Keep `adminPermissionsEnabled: false` on backstage + rhbk-iam realms |

Healthy installs: heal exits immediately (“no FGAP heal needed”). Wipe only
runs when **backstage** lockout is detected (hub-only workshop data is re-imported).

Scaffolder step "Authenticate provisioner (realm cv)" `unauthorized_client`
is often: (1) cv Admin API 403 so sync never PUTs `backstage-provisioner`,
and/or (2) Keycloak's live client secret (autogenerated, ~38 chars) != Vault
(24 chars). After cv Admin API returns 200, `rhbk-iam-sync-client-secrets`
must complete (`OK cv/backstage-provisioner`). Manual recovery: restart
`keycloak-0`, then delete/recreate that Job (do not wipe Postgres).

**After PVC wipe, Keycloak must restart** — otherwise it stays Ready against an
empty DB (`offline_user_session` / `jgroups_ping` missing) and SSO shows
“Internal Server Error” while Admin API keeps returning 403. The heal Job now
deletes `keycloak-0` immediately after Postgres is Ready so Liquibase recreates
the schema before realm re-import.

**Manual fallback** (if an older tag is still installed):
```bash
oc delete job keycloak-fgap-heal -n keycloak-system --ignore-not-found
oc delete keycloakrealmimport backstage-realm realm-cv realm-maas realm-neuroface -n keycloak-system --ignore-not-found
oc scale statefulset postgresql-db -n keycloak-system --replicas=0
oc delete pod postgresql-db-0 -n keycloak-system --force --grace-period=0
oc delete pvc data-postgresql-db-0 -n keycloak-system
oc scale statefulset postgresql-db -n keycloak-system --replicas=1
# REQUIRED — without this SSO stays Internal Server Error:
oc delete pod keycloak-0 -n keycloak-system --force --grace-period=0
oc annotate application rhbk-iam developer-hub -n vp-gitops argocd.argoproj.io/refresh=hard --overwrite
oc delete job developer-hub-sync-backstage-realm-secrets keycloak-fgap-heal -n keycloak-system --ignore-not-found
```

### 3.5 Missing "Computer Vision API" / Swagger definitions in Developer Hub catalog

**Symptom:** the NeuroFace and Computer Vision API entries (with their
Swagger/OpenAPI cards) don't show up under Developer Hub's API catalog on a
hub-only CPU install, even though the underlying HTTPRoutes work fine.

**Cause:** `charts/all/neuroface-gateway/templates/apiproducts.yaml` (the
Kuadrant `APIProduct` CRs the Developer Hub Kuadrant plugin needs to render
the catalog card) was gated on `{{- if or .Values.clusters.east.domain
.Values.clusters.west.domain }}` only -- i.e. hub+spoke topology. Hub-only
CPU installs (`hubLocal.enabled: true`) target the exact same
`neuroface-app-lb`/`neuroface-cv-lb` HTTPRoutes but never got the
`APIProduct` CRs created.

**Pattern fix (already applied):** the guard now also fires when
`hubLocal.enabled` is `"true"`.

Connectivity Link console **Definition** tab reads `APIProduct.status.openapi.raw`,
not `docsURL`. Catalog `/definition` URLs are Developer Hub SPA HTML. Chart
`job-sync-apiproduct-openapi.yaml` PostSync-patches status and a CronJob
(`*/10 * * * *`) repeats it. SA/RBAC are persistent (not PostSync hooks).

**Hub-local 503 `upstream_host: null`:** Istio ambient does not populate EDS
for ExternalName Services. Hub-only HTTPRoutes must `backendRef` the real
ClusterIP (`neuroface-frontend` in `neuroface-hub`, `yolo-ppe-serving` in
`neuroface-cv`) plus `ReferenceGrant`s. Do not label `neuroface-hub`
`istio.io/dataplane-mode=ambient` without confirming ztunnel namespace.

**Recovery on an already-installed cluster (before the ArgoCD app resyncs):**
```bash
DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
helm template neuroface-gateway charts/all/neuroface-gateway \
  --set clusterDomain="${DOMAIN}" --set hubLocal.enabled=true \
  --show-only templates/apiproducts.yaml | oc apply -f -
```
Verify: `oc get apiproducts.devportal.kuadrant.io -A` should list
`neuroface-openapi` and `neuroface-cv-openapi` in `neuroface-gateway-system`.

### 3.6 YOLO PPE InferenceService storage-initializer S3 403 Forbidden

**Symptom:**
```
S3 error for s3://models/ppe-detection/model: An error occurred (403) when
calling the HeadBucket operation: Forbidden
```
`yolo-ppe-serving-predictor` stuck `Init:CrashLoopBackOff`.

**Cause:** `vault-secrets-bootstrap`'s job seeds `secret/data/hub/
minio-credentials` with **random placeholder** values (it has no way to
know GitLab MinIO root credentials at that point — those come from chart-
managed MinIO / `gitlab-minio-secret` under GitLab chart 10.x).
`charts/all/spoke-neuroface-cv/templates/job-model-seed.yaml` already reads
the REAL `gitlab-minio-secret` and overwrites Vault with the correct
values as its last step -- this is not a missing feature, just a job that
needs `gitlab-minio-secret` to exist (created by `gitlab-external-secrets`
+ MinIO STS in the gitlab-operator chart). The job runs as **PostSync** so
it does not block Kafka/IS sync waves; `spoke-neuroface-cv` also has
`ignoreDifferences` on `InferenceService` `.status`, and the job
force-syncs `ExternalSecret/aws-connection-ppe-models` after writing Vault.

**If this still shows up:** it almost always means `spoke-neuroface-cv`'s
Argo CD sync got stuck/retried before the model-seed Job could run (see
diagnosis below) rather than a code problem -- the fixes above are already
in place.

**Diagnosis:**
```bash
oc get application spoke-neuroface-cv -n vp-gitops -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status,OP:.status.operationState.phase,MSG:.status.operationState.message
oc exec vault-0 -n vault -- vault kv get secret/hub/minio-credentials   # if still the placeholder rand() value, the hook hasn't run
```

**Recovery:**
```bash
oc annotate application spoke-neuroface-cv -n vp-gitops argocd.argoproj.io/refresh=hard --overwrite
# if the sync stays stuck retrying, clear it and let it retry clean:
oc patch application spoke-neuroface-cv -n vp-gitops --type json -p '[{"op":"remove","path":"/operation"}]'
oc annotate application spoke-neuroface-cv -n vp-gitops argocd.argoproj.io/refresh=hard --overwrite
# once synced, confirm:
oc logs -n gitlab-system -l job-name=ppe-model-seed --tail=10   # should end with "Vault minio-credentials: synced"
oc delete pod -n neuroface-cv -l serving.kserve.io/inferenceservice=yolo-ppe-serving
```

### 3.7 models-as-a-service Degraded: Authorino Service `spec.ports: Required value`

**Symptom:** `models-as-a-service` Argo CD app stuck Degraded / sync retrying with:
```
Service "authorino-authorino-authorization" is invalid: spec.ports: Required value
```

**Cause (fixed in pattern):** an older chart revision created a ports-less
Service via ServerSideApply in the wrong namespace. Authorino's Service is
owned by RHCL; this pattern must only annotate it.

**Automated fix:** `authorino-service-cert.yaml` is now a PostSync Job that
waits for the operator-managed Service (tries `kuadrant-system` then
`redhat-connectivity-link-operator`) and annotates it for serving certs.

### 3.8 Swagger "Try it out" → Failed to fetch (CORS origin or Authorino TLS)

**Symptom:** Developer Hub or OpenShift console Swagger "Try it out" shows
Failed to fetch / CORS. Preflight may be 204/200.

**Two independent causes:**

1. **Lua OPTIONS 204 without CORS headers:** a native `envoy.filters.http.cors`
   policy only covers **matched** HTTPRoutes. Lua then answered OPTIONS with
   empty 204 so `/` (Gateways table host) and `/mcp` (disabled on hub-only)
   had no `Access-Control-Allow-Origin`; Swagger reports that as CORS.
   **Fix:** destub-wso2 Lua only — OPTIONS 204 **with** ACAO/Allow-Headers,
   `envoy_on_response` `replace()` of ACAO to `*` (never `add()`, never pair
   `*` with `Allow-Credentials`). Do **not** also set CORS on the HTTPRoute
   or a second cors filter (duplicate ACAO). Workshop AuthPolicies accept
   `APIKEY` and `Bearer` (console Swagger sends Bearer).

2. **Authorino TLS/issuer:** Authorino cannot fetch OIDC discovery from
   `https://sso.<apps>/realms/cv/.well-known/openid-configuration` because the
   route cert is signed by OpenShift `router-ca` and `SSL_CERT_FILE` pointed at
   a missing path (or only service-CA). AuthPolicy then 401s every JWT;
   browsers report that as CORS "Failed to fetch". A second failure mode is
   `issuerUrl` still pointing at `keycloak.` while tokens carry `iss=https://sso...`.

**Automated fix:** `models-as-a-service` `authorino-tls-env` Job mounts a CA
bundle (system + `router-ca` + service-CA) at
`/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt` and sets
`SSL_CERT_FILE`. AuthPolicy `issuerUrl` defaults to `sso.` in
`neuroface-gateway` / `workshop-kuadrant-apis`.

**Live check:**
```bash
DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
HUB="https://developer-hub.${DOMAIN}"
CON="https://console-openshift-console.${DOMAIN}"
curl -sk -D - -o /dev/null -X OPTIONS "https://workshop-apis.${DOMAIN}/" \
  -H "Origin: ${HUB}" -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization"
# expect 204 and Access-Control-Allow-Origin (even with no HTTPRoute on /)
curl -sk -D - -o /dev/null -X OPTIONS "https://neuroface-cv.${DOMAIN}/health" \
  -H "Origin: ${CON}" -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization"
# expect 2xx and Access-Control-Allow-Origin
curl -sk -o /dev/null -w "%{http_code}\n" https://neuroface-cv.${DOMAIN}/health
# 401 without token; 200 with Bearer from sso
```

### 3.9 istio-ztunnel Invalid: Unsupported ZTunnel version

**Symptom:**
```
ZTunnel.sailoperator.io "default" is invalid: spec.version: Unsupported value: "v1.28.8"
```
(enum only lists `v1.26.x` / `v1.24.x` on Service Mesh 3.1).

**Automated fix:** `charts/all/istio-ztunnel` leaves `spec.version` unset by
default so the Sail CRD default applies. Pin only via overlay when you know
the enum (`values-hub-rhpds.yaml` for Scenario D).

**Check on a live cluster:**
```bash
oc get crd ztunnels.sailoperator.io -o jsonpath='{.spec.versions[-1].schema.openAPIV3Schema.properties.spec.properties.version.enum}'
oc get istio -A -o custom-columns=NAME:.metadata.name,VER:.spec.version
```

### 3.10 OIDC self-service picker missing "Computer Vision API"

**Symptom:** Developer Hub → Create → OIDC credentials self-service → Target API
dropdown empty or missing Computer Vision (MaaS may still appear).

**Cause:** Kuadrant APIProduct entity provider owns `api:default/neuroface-cv-openapi`
(same `metadata.name` as the APIProduct, required for "View in Catalog"). That
overwrites the iam-realms catalog entity and drops
`workshop/oidc-self-service-target: "true"`, so an annotation-only EntityPicker
filter hides it. `maas-openapi` stays visible because no APIProduct steals that name.

**Pattern fix:** scaffolder `catalogFilter` OR-matches `neuroface-cv-openapi` by
name in addition to the annotation. Workshop targets are **Computer Vision + MaaS
only** (NeuroFace app API and partner PoCs Aura / Agenda de Vencimientos are not
self-service targets).

### 3.9b OIDC self-service step fails: proxy 500 / SELF_SIGNED_CERT_IN_CHAIN

**Symptom:** scaffolder step "Authenticate provisioner (realm cv)" fails with
`Error occurred while trying to proxy: localhost:7007/realms/cv/...` (HTTP 500).

**Cause:** Backstage `http-proxy-middleware` does not honor
`NODE_TLS_REJECT_UNAUTHORIZED` and rejects the cluster SSO/route TLS chain.

**Pattern fix:** `proxy.endpoints['/keycloak']` and
`['/keycloak-provisioner-token']` set `secure: false` (same as `/k8s-api`).
### 3.10 Keycloak `Invalid parameter: redirect_uri` after manual realm reimport

**Symptom:** OIDC login reaches Keycloak then `Invalid parameter: redirect_uri`.

**Cause:** `KeycloakRealmImport` was applied with `hubClusterDomain=apps.${DOMAIN}`
when `DOMAIN` from `oc get ingresses.config/cluster` was already `apps.<cluster>`,
producing redirect URIs like `https://developer-hub.apps.apps.<cluster>/...`.

**Fix:** set `global.localClusterDomain` / `global.hubClusterDomain` to the ingress
domain **once** (already `apps....`), never prefix another `apps.`. Patch the
`developer-hub` client redirectUris via Admin API if the realm was already imported
(KeycloakRealmImport does not update existing realms).

## 4. Quick health check after all fixes

```bash
DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
curl -sk -o /dev/null -w "sso:%{http_code}\n" "https://sso.${DOMAIN}/"
curl -sk -o /dev/null -w "dh:%{http_code}\n" "https://developer-hub.${DOMAIN}/"
curl -sk "https://developer-hub.${DOMAIN}/api/auth/oidc/start?env=production" -o /dev/null -w "oidc-start:%{http_code}\n"
curl -sk -o /dev/null -w "gitlab:%{http_code}\n" "https://gitlab.apps.${DOMAIN#apps.}/"
oc get authpolicy -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,ACCEPTED:.status.conditions[0].status
oc get apiproducts.devportal.kuadrant.io -A
```
Expect `sso:302`, `dh:200`, `oidc-start:302` (not 500/503), `gitlab:200`
(once webservice pods are 2/2 Running), all AuthPolicy `True`, and the
`neuroface-*-openapi` APIProducts present.

### 4.1 Demo gate — Connectivity Link apps Synced (before recording Arcade)

After `main` includes `connectivityLinkArgoCD` tuning in `values-hub.yaml`,
these apps should report **Synced** even though the Kuadrant operator mutates
`Authorino`/`Limitador` spec and policy `.status` fields live:

```bash
for app in workshop-kuadrant-apis neuroface-gateway models-as-a-service developer-hub rhbk; do
  oc get application "$app" -n vp-gitops -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
done
```

Expect all five `Synced` / `Healthy` (or `Progressing` only while PostSync
hooks still run — wait for `kuadrant-operator-readiness` in
`neuroface-gateway-system` to complete before declaring failure).

If an app stays `OutOfSync` on `Authorino` or `APIProduct` **after** hooks
finish, confirm the Application has `syncOptions: RespectIgnoreDifferences=true`
and the shared `ignoreDifferences` block from `values-hub.yaml` (re-sync the
`ia-computer-vision` pattern Application or hard-refresh the child app).

Workshop Kuadrant restart hook is wait-only; operator restart is owned by
`neuroface-gateway` `kuadrant-operator-readiness` (do not manually restart
both).

### 4.2 Cluster Bot launch (hub-only demo)

```
workflow-launch openshift-e2e-aws 4.20 "COMPUTE_NODE_TYPE=m6a.4xlarge","CONTROL_PLANE_INSTANCE_TYPE=m6a.2xlarge","COMPUTE_NODE_REPLICAS=4"
```

No `--lease` on this command (see section 1). Budget ~3h after `auth` for install + demo.

Then: Validated Patterns Operator →
`oc apply -f examples/pattern-cr/hub-only-cpu.yaml` (targetRevision `main`).
Do **not** add `values-hub-rhpds.yaml` or `values-hub-odf-datagrid.yaml`.
Allow ~1–2 h for Argo CD, then run §4 and §4.1 before Arcade recording.
