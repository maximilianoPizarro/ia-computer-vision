---
name: cluster-bot-install
description: >-
  Provision a fresh OpenShift cluster via Cluster Bot (ci-chat-bot) sized for
  the ia-computer-vision hub-only CPU pattern, and recover from the known
  first-boot issues a cluster with NO pre-installed operators hits (cert-manager
  missing, RHBK/ESO sync-wave races, Keycloak Fine-Grained Admin Permissions
  locking out the backstage realm, Kuadrant Gateway API dependency race). Use
  when asked to launch a Cluster Bot cluster for this pattern, or when
  diagnosing SSO 503s, Developer Hub "unauthorized_client"/"Realm does not
  exist" errors, GitLab stuck in "Preparing" (cert-manager missing OR chart
  10.x missing external Postgres/Redis/MinIO), invalid Kuadrant AuthPolicy, or
  missing API Products/Swagger definitions right after a fresh install.
---

# Cluster Bot install -- ia-computer-vision hub-only CPU

## 1. Launch command (verified sizing)

```
workflow-launch openshift-e2e-aws 4.20 "COMPUTE_NODE_TYPE=m6a.4xlarge","CONTROL_PLANE_INSTANCE_TYPE=m6a.2xlarge","COMPUTE_NODE_REPLICAS=4"
```

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
(up to 6 Kuadrant-only restarts). `workshop-kuadrant-apis` has a secondary
PostSync restart hook as a safety net.

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
| `keycloak-fgap-heal` (developer-hub PostSync wave 5) | Detects FGAP (403 or truncated realm) → deletes realm-imports → wipes `postgresql-db` PVC → hard-refreshes `rhbk-iam` + `developer-hub` → waits until Admin API is healthy |
| `developer-hub-sync-backstage-realm-secrets` (wave 6) | Waits for clients; fail-fast on Admin API 403 (does not spin) |
| `rhbk-iam-sync-client-secrets` | Same wait/retry + 403 fail-fast for realm `cv` |
| Realm CRs | Keep `adminPermissionsEnabled: false` on backstage + rhbk-iam realms |

Healthy installs: heal exits immediately (“no FGAP heal needed”). Wipe only
runs when lockout is detected (hub-only workshop data is re-imported).

**Manual fallback** (if an older tag is still installed):
```bash
oc delete keycloakrealmimport backstage-realm realm-cv realm-maas realm-neuroface -n keycloak-system --ignore-not-found
oc scale statefulset postgresql-db -n keycloak-system --replicas=0
oc delete pod postgresql-db-0 -n keycloak-system --force --grace-period=0
oc delete pvc data-postgresql-db-0 -n keycloak-system
oc scale statefulset postgresql-db -n keycloak-system --replicas=1
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

### 3.8 Swagger "Try it out" → Failed to fetch (looks like CORS, is Authorino TLS/issuer)

**Symptom:** Developer Hub Swagger "Try it out" on `neuroface-cv.../health`
with a Bearer token shows Undocumented / Failed to fetch / Possible Reasons:
CORS. Preflight `OPTIONS` already returns 204 with CORS headers.

**Cause (not Envoy CORS):** Authorino could not fetch OIDC discovery from
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
curl -sk -o /dev/null -w "%{http_code}\n" https://neuroface-cv.apps.<domain>/health
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
