---
name: vp-helm-values
description: >-
  Validated Patterns Helm charts and values files conventions for ia-computer-vision.
  Use when creating or editing values-*.yaml, Chart.yaml, Helm templates in
  charts/all/, overrides/, or any Helm-related configuration. Covers clusterGroup
  structure, sync waves, ArgoCD annotations, and VP chart dependencies.
---

# VP Helm Charts and Values Files -- ia-computer-vision

## values-global.yaml structure

```yaml
global:
  pattern: ia-computer-vision
  singleArgoCD: true
  argoNamespace: openshift-gitops
  options:
    useCSV: false
    syncPolicy: Automatic
    installPlanApproval: Automatic

main:
  clusterGroupName: hub   # maps to values-hub.yaml
  multiSourceConfig:
    enabled: true
    clusterGroupChartVersion: "0.9.*"
    helmRepoUrl: https://charts.validatedpatterns.io
```

Key rules:
- `global.pattern` must match repository name
- `main.clusterGroupName` determines which `values-{name}.yaml` is loaded
- `singleArgoCD: true` consolidates into VP Operator managed instance
- Do NOT add `openshift-gitops-operator` subscription (VP Operator handles it)
- `global.argoNamespace` (set by you in `values-global.yaml`, e.g. `vp-gitops`) is the **input** telling the VP Operator where to put the single ArgoCD instance. It is a *different key* from `global.vpArgoNamespace`, which is what actually gets injected into local chart Helm renders at runtime (confirmed via `oc get application <app> -o jsonpath='{.spec.source.helm.parameters}'`). Local chart templates that need to reference the ArgoCD namespace/instance name must read `.Values.global.vpArgoNamespace`, not `.Values.global.argoNamespace` (which is simply absent at chart-render time and silently evaluates to the Helm `default`).

## values-{clusterGroupName}.yaml structure

Three-section layout: namespaces, subscriptions, applications.

```yaml
clusterGroup:
  name: hub               # must match the clusterGroupName
  namespaces:
    open-cluster-management:   # dict format (allows operatorGroup, labels)
    vault:
    my-namespace:
      operatorGroup: true
      targetNamespaces:
        - my-namespace

  subscriptions:
    my-operator:
      name: my-operator
      namespace: openshift-operators    # default
      channel: stable
      source: redhat-operators          # default

  argoProjects:
    - hub
    - platform
    - security

  sharedValueFiles:
    - '/overrides/values-{{ $.Values.global.clusterPlatform }}.yaml'
    - '/overrides/values-{{ $.Values.global.clusterVersion }}-{{ $.Values.clusterGroup.name }}.yaml'

  applications:
    my-app-published:
      name: my-app
      namespace: my-namespace
      argoProject: hub
      chart: my-chart              # VP published chart
      chartVersion: 0.1.*
      syncWave: '3'

    my-app-local:
      name: my-app-local
      namespace: my-namespace
      argoProject: platform
      path: charts/all/my-app      # local chart
      syncWave: '5'
      overrides:
        - name: clusterName
          value: east

  managedClusterGroups:
    east:
      name: east
      acmlabels:
        - name: clusterGroup
          value: east
    west:
      name: west
      acmlabels:
        - name: clusterGroup
          value: west
```

## Sync waves (ordering)

Use `syncWave` in applications or `argocd.argoproj.io/sync-wave` annotation in templates:

### Hub sync waves
| Wave | Purpose | Applications |
|------|---------|-------------|
| 0 | Platform base | openshift-gitops (sets only `ArgoCD/vp-gitops` `spec.localUsers` — see "ArgoCD tuning (hub)" below), platform-users |
| 1 | Operators + ACM | observability, acm |
| 2 | Secrets infrastructure | vault, openshift-external-secrets, rhbk |
| 3 | Developer tools + MCP | gitlab-operator, **argocd-mcp** |
| 4 | Developer portal | developer-hub |
| 5 | AI + workshop | openshift-ai-hub, showroom, workshop-registration |
| 6 | Multi-cluster + native MaaS | neuroface-gateway, acm-hub-spoke, **models-as-a-service**, workshop-kuadrant-apis |
| 7 | Security + IDE | acs-init-bundle-sync, devspaces |
| 10 | Console UI | console-links |

### Spoke sync waves
| Wave | Purpose | Applications |
|------|---------|-------------|
| 0 | Platform base | openshift-gitops, platform-users, **argocd-local-users** |
| 1 | Service Mesh + ESO + MCP export | servicemesh-config, openshift-external-secrets, **argocd-mcp-spoke-export** |
| 2 | Observability | observability |
| 3 | Security | acs-secured-cluster |
| 5 | CV inference | spoke-neuroface |
| 6 | CV model serving | spoke-neuroface-cv |
| 7 | Cross-cluster + IDE | spoke-interconnect, devspaces |
| 10 | Console UI | console-links |

## Chart.yaml (root umbrella)

```yaml
apiVersion: v2
name: ia-computer-vision
description: AI Computer Vision at the Edge -- Validated Pattern
version: 0.1.0
type: application
maintainers:
  - name: Maximiliano Pizarro
    email: mapizarr@redhat.com
```

The `clustergroup` dependency is resolved via `multiSourceConfig` (not as a Chart.yaml dependency) when `multiSourceConfig.enabled: true`.

## Local chart conventions (charts/all/{name}/)

### Chart.yaml
```yaml
apiVersion: v2
name: {chart-name}
description: {what this chart configures}
type: application
version: 0.1.0
maintainers:
  - name: Maximiliano Pizarro
    email: mapizarr@redhat.com
```

### Template annotations
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "4"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    argocd.argoproj.io/sync-options: ServerSideApply=true   # for CRDs
```

### Templated values
Use `.Values` for chart-specific values and `.Values.global` for pattern globals:
```yaml
spec:
  namespace: {{ .Values.global.pattern }}-{{ .Values.clusterName | default "hub" }}
```

## ArgoCD tuning (hub) — NOT done via this chart anymore

`charts/all/openshift-gitops`'s `ArgoCD` CR template used to also patch `controller.resources`, `resourceExclusions`, `applicationSet`/`redis`/`repo`/`sso`/`server` resources, and `resourceHealthChecks` on `ArgoCD/vp-gitops`. **All of that was removed** — the chart's `templates/argocd.yaml` now sets **only** `spec.localUsers`. Reason: on the hub (`global.singleArgoCD: true`), `patterns-operator` itself unconditionally rebuilds and `Update()`s the *entire* `ArgoCD` spec on every reconcile (a confirmed upstream bug, [validatedpatterns/patterns-operator#749](https://github.com/validatedpatterns/patterns-operator/issues/749) — see the `vp-pattern-dev` skill for the full root-cause writeup with exact source lines). Any field this chart also set got fought over field-by-field with the operator's own hardcoded baseline, causing continuous Deployment/StatefulSet churn and `vp-gitops-application-controller` pod restarts every ~15-30s. **Do not re-add `controller`/`server`/`redis`/`repo`/`sso`/`resourceExclusions`/`resourceHealthChecks`/`rbac` to this chart's ArgoCD CR template** — those fields are effectively owned by `patterns-operator`'s hardcoded default now (it wins every time regardless), and duplicating them here only reintroduces the churn without changing the live outcome. `spec.localUsers` is the one field `patterns-operator`'s `newArgoCD()` doesn't set, which is why it's safe (and necessary, for the `argocd-mcp` `ai-agent` local user) to keep setting it from this chart.

## ArgoCD tuning (spokes)

Via `clusterGroup.argoCD.env` in values-east/west.yaml:
```yaml
clusterGroup:
  argoCD:
    env:
      - name: GOMEMLIMIT
        value: "3600MiB"
      - name: GOMAXPROCS
        value: "4"
```

## Overrides

Platform-specific overrides go in `overrides/`:
- `values-AWS.yaml` -- AWS-specific settings
- `values-{{ clusterPlatform }}.yaml` -- auto-loaded via `sharedValueFiles`
- `values-{{ clusterVersion }}-{{ clusterGroupName }}.yaml` -- version+role specific

## Secrets in values files

Never put actual secrets in values files. Use the VP secrets framework:
- Define secrets in `values-secret.yaml.template` (schema v2.0)
- Vault injects secrets via External Secrets Operator
- Reference secrets in charts via ESO `ExternalSecret` CRs

## VP chart overrides (passwordVaultKey pattern)

VP published charts like `rhbk` use `passwordVaultKey` to reference Vault secrets. These must be passed as overrides in values-hub.yaml:

```yaml
rhbk:
  overrides:
    - name: keycloak.adminUser.passwordVaultKey
      value: secret/data/hub/rhbk-credentials
    - name: keycloak.postgresqlDb.passwordVaultKey
      value: secret/data/hub/rhbk-credentials
```

The Vault path follows the convention `secret/data/hub/{secret-name}` where `{secret-name}` matches the `name` field in `values-secret.yaml.template`.

## Known Helm/ArgoCD pitfalls

1. **ExternalSecret `remoteRef.key` empty**: VP charts using `passwordVaultKey` require the key as an override. Without it, the ExternalSecret validation fails with `Required value`.
2. **ignoreDifferences for ExternalSecret**: When ExternalSecret points to a Vault path that doesn't exist yet, ArgoCD marks the app as Degraded. Add `ignoreDifferences` on `.status` to prevent blocking.
3. **RHDH operator regenerates ConfigMaps**: The Backstage operator creates `backstage-dynamic-plugins-developer-hub` from `dynamic-plugins-rhdh` ConfigMap. Patches to the generated ConfigMap are overwritten on next reconciliation. Always patch the source `dynamic-plugins-rhdh` ConfigMap.
4. **Community plugins not in RHDH image**: `backstage-community-plugin-{ocm,tekton,topology,kafka,quay,acr,rbac}` must be `disabled: true` in the dynamic plugins ConfigMap for RHDH 1.10.
5. **Duplicate YAML keys crash RHDH**: The `catalog.providers.gitlab` config must not have two `schedule:` keys. RHDH uses a strict YAML parser that throws `YAMLParseError: Map keys must be unique` and CrashLoopBackOff.
6. **OperatorGroup AllNamespaces**: RHCL and COO operators require `operatorGroup: true` + `targetNamespaces: []` (AllNamespaces). Without this in spoke namespaces, CSVs fail with `OwnNamespace InstallModeType not supported`.
7. **KServe CRD deadlock on spokes**: Do NOT place `DataScienceCluster` CR in the same chart that uses KServe CRDs (`spoke-neuroface-cv`). Place the DSC in a lower-wave chart that already syncs successfully (`observability` wave 2).
8. **Service Mesh required on hub**: The `neuroface-gateway` uses `gatewayClassName: istio` which requires an Istio control plane. Hub must have `servicemeshoperator3` subscription and `servicemesh-config` app (VP `servicemesh` chart, `profile: ambient`) at wave 5 before the gateway at wave 6.
9. **ACM auto-import SA permissions**: The CronJob SA needs `managedclustersets/join`, `managedclusters/accept`, and namespace `create` beyond basic `managedclusters` CRUD. See `spoke-auto-import-cronjob.yaml` ClusterRole.
10. **Spoke import tokens**: Use `acm-import` SA (auto-created by `platform-users` chart), not `kube-system:default` which lacks `cluster-admin`.

### Spoke sync waves
| Wave | Purpose | Applications |
|------|---------|-------------|
| 0 | Platform base | platform-users (creates acm-import SA) |
| 1 | Service Mesh | servicemesh-config (VP chart, ambient) |
| 2 | Observability + ESO | observability (includes spoke DSC for KServe CRDs), openshift-external-secrets |
| 3 | Security | acs-secured-cluster |
| 4 | Cross-cluster | spoke-interconnect |
| 5 | CV inference | spoke-neuroface |
| 6 | CV model serving | spoke-neuroface-cv |
| 7 | IDE | devspaces |
| 10 | Console UI | console-links |

11. **GitLab operator external URL**: The GitLab CR `global.hosts.hostSuffix: gitlab` generates hostname `gitlab-gitlab.apps.<domain>`. The operator Ingress->Route translation creates a Route WITHOUT TLS. HTTPS to this hostname returns 503. Override with `global.hosts.gitlab.name: gitlab.apps.<domain>` (via `gitlab-operator.host` Helm helper) and add `route.openshift.io/termination: edge` in `global.ingress.annotations`.
12. **RHDH publish:gitlab settings**: The RHDH GitLab scaffolder module does NOT accept `description` or `repoVisibility` as top-level inputs. Use `settings.description` and `settings.visibility` instead. Top-level `description` causes `InputError: instance is not allowed to have the additional property`.
13. **PostSync jobs with cross-namespace RBAC**: ArgoCD apps with `destinations: *` in their project CAN create Roles/RoleBindings in other namespaces (e.g., `developer-hub` app creating RBAC in `vault` and `gitlab-system`). Verify the ArgoCD project allows `*` destinations. Use `argocd.argoproj.io/sync-wave: "1"` on RBAC resources so they exist before the Job (wave 8) runs.
14. **ExternalSecret v1 vs v1beta1**: Use `external-secrets.io/v1` on OCP 4.20+. The `v1beta1` API is not served by default.
15. **Gateway HA via parametersRef**: Istio Gateway API ignores `spec.replicas`. Use `spec.infrastructure.parametersRef` pointing to a ConfigMap with `deployment: | spec: replicas: N`.
16. **ApplicationSet scmProvider SSH error**: When GitLab repos are in `deletion_scheduled` state, ArgoCD scmProvider tries to clone them and fails with `SSH_AUTH_SOCK not-specified`. This is transient and self-resolves when repos finish deletion.
17. **Vault root token path**: VP Vault chart stores the root token at `/vault/data/root-token` inside the `vault-0` pod. Use this for automated `vault kv patch` operations from PostSync jobs.
18. **GitLab 18+ namespace_settings nil**: Groups created via `gitlab-rails runner` do NOT auto-create `namespace_settings`. Login to group pages returns 500. Always call `group.create_namespace_settings!` after `Group.find_or_create_by!` in bootstrap scripts.
19. **Minio credentials in GitLab**: GitLab's bundled Minio generates random access keys stored in `gitlab-minio-secret`. Never hardcode `minio/minio123`. Extract real keys from the secret and sync to Vault for spoke consumption.
20. **Spoke namespace pre-creation**: Spokes need `vault`, `istio-system`, and other infrastructure namespaces declared in `clusterGroup.namespaces`. Missing namespaces cause ESO and Istio failures at higher waves.
21. **`global.argoNamespace` does not exist** — use `global.vpArgoNamespace` (falls back to `"vp-gitops"` for this pattern). A chart that hardcodes `namespace: openshift-gitops` for the single ArgoCD instance's own CR (or anything that must target it, like a rollout-restart Job) will silently operate on the wrong object forever; the real instance for this pattern is named/namespaced `vp-gitops`. Always guard with the nil-safe pattern used elsewhere: `{{- $argoNs := "vp-gitops" -}}{{- if .Values.global -}}{{- $argoNs = .Values.global.vpArgoNamespace | default $argoNs -}}{{- end -}}`.
22. **Two Applications must never both own a cluster-singleton CR**: `Kuadrant`, `Authorino`, `Limitador`, `DataScienceCluster`, `Kiali`, `OSSMConsole` are all effectively cluster-singletons even though they are namespaced objects. Declaring "the same" one from two different charts causes them to race, and whichever Application gets pruned/recreated first can tear down the operator-managed workload (pods) cluster-wide. Run a `(kind, namespace, name)` collision scan across every rendered chart (both `clusterRole=hub` and `clusterRole=spoke`) before adding a new chart that creates any CR — see the `vp-pattern-dev` skill for the exact scan script.
23. **The shared `clustergroup` chart's Subscription template only supports `spec.config.env`** — not `spec.config.resources`, `nodeSelector`, `tolerations`, etc. (confirmed by reading `common/clustergroup/templates/core/subscriptions.yaml` directly from GitHub). If an operator needs a resource-limit override (common for OLM defaults that OOM under real load, e.g. gitlab-operator's 300Mi), declare that Subscription ONLY in a local chart's own template (which can render any field), and do NOT also list it under `clusterGroup.subscriptions` in the values file — the clustergroup-rendered copy will win the object and silently strip the override on every sync.
24. **Cross-namespace RBAC for hook Jobs**: whenever a Job's script does `oc exec -n <ns>` or `oc get pods -n <ns> -l ...` for a namespace OTHER than the Job's own, it needs a separate `Role`/`RoleBinding` scoped to that namespace (see `gitlab-token-setup-exec-vault`, `gitlab-workshop-bootstrap-exec-vault` for the pattern). A `Role` in the Job's own namespace never grants this. Failures can be silent (stderr swallowed, checked with `if`) — always grep for `oc exec\|oc get pods` in hook Job scripts and verify RBAC coverage for every namespace touched, not just the Job's own.
25. **Namespace lists shared between hub/spoke renders of the same chart must be mutually exclusive, never concatenated**: if a template builds a namespace list starting with the hub-only set and then appends the spoke-only set when a spoke-indicating value is set, spokes end up with BOTH sets and try to create resources in namespaces that only exist on the hub. Use `if/else` to select one list or the other, never `concat` across cluster roles.
26. **CEL expressions in Kuadrant policies (`RateLimitPolicy`/`AuthPolicy` counters, conditions)**: use single quotes for string literals inside header/map accessors — `request.headers['x-forwarded-for']`, not `request.headers["x-forwarded-for"]`. Limitador's descriptor-file serialization mangles the double-quote-inside-double-quote case and crashes with a syntax error (`Invalid limit file`), CrashLoopBackOff.
27. **`values-secret.yaml.template` must declare every Vault path any `ExternalSecret` reads** — not just the ones a human remembers to add. Systematic check: extract every `remoteRef.key` + `remoteRef.property` pair from every `ExternalSecret` template across `charts/all/*/templates/*.yaml`, normalize the literal (non-templated) `secret/(data/)?hub/<name>` paths, and confirm a matching `secrets[].name` (`<name>`) with a `fields[].name` (`<property>`) exists. A secret that only exists because someone populated Vault manually during development will never get created by `./pattern.sh make load-secrets` on a fresh install.
28. **Scaffolder template `spec.output.text` must be `[{title, content}, ...]`**, not an array of plain strings — the catalog processor rejects the whole Template entity with only a warning-level log line (`ScaffolderEntitiesProcessor ... /spec/output/text/0 must be object`), so the template silently never appears in the catalog with no user-visible error.

## Critical values-hub.yaml constraints (Jun 29, 2026)

### keycloak-system must NOT have ambient mesh labels
Do NOT add `istio.io/dataplane-mode: ambient` labels to the `keycloak-system` namespace. The ztunnel proxy breaks DNS resolution inside Keycloak pods, causing `UnknownHostException: postgresql-db` and CrashLoopBackOff. Keycloak must remain outside the service mesh.

```yaml
# WRONG - causes CrashLoopBackOff
keycloak-system:
  labels:
    istio.io/dataplane-mode: ambient

# CORRECT - no mesh labels
keycloak-system:
```

### keycloak.hostname must be "sso"
The AuthPolicy `extAuth` redirects to `sso.apps.<domain>`. The Keycloak CR hostname MUST match. Override via `rhbk` chart overrides:

```yaml
rhbk:
  overrides:
    - name: keycloak.hostname
      value: sso
```

Without this, cookies are issued on `keycloak.apps.<domain>` but validated on `sso.apps.<domain>`, causing "Restart login cookie not found" errors.

### spoke-neuroface-cv modelStorage should use useVault: true
GitLab's bundled Minio auto-generates credentials. Hardcoded `minio/minio123` will always get S3 403. The gitlab-bootstrap job syncs real Minio credentials to Vault. Spoke values must reference Vault:

```yaml
spoke-neuroface-cv:
  overrides:
    - name: modelStorage.useVault
      value: "true"
```

### kuadrant.oidc.enabled controls AuthPolicy on main demo route
The `kuadrant.oidc.enabled` flag (default `false`) in `neuroface-gateway/values.yaml` determines whether the `neuroface-app-lb` HTTPRoute gets an OIDC AuthPolicy. When enabled, XHR calls to `/api/health` are blocked (the frontend can't determine cluster identity). Keep disabled unless SSO on the main demo page is explicitly required. OIDC remains active on `neuroface-cv-lb` only.

```yaml
# neuroface-gateway/values.yaml
kuadrant:
  oidc:
    enabled: false    # true = AuthPolicy on neuroface-app-lb (blocks API calls)
  rateLimitPolicy:
    limit: 120        # req/min (increased from 30 for multi-user demos)
```

### ArgoCD hook annotations on Jobs cause duplicates
Do NOT use `argocd.argoproj.io/hook: PostSync` on Jobs that should persist across syncs (like `download-model`). ArgoCD creates a separate hook Job AND a regular resource Job, causing conflicts. Use plain sync-wave ordering instead.

### Spokes need the `imperative` namespace declared
The VP-published `acm` chart's `hub-ca-config-policy` (a standard ACM Policy, not something in this repo's own charts) creates a `trusted-hub-bundle` ConfigMap in a namespace called `imperative` on every managed cluster. If `imperative` is not declared in `clusterGroup.namespaces` for `values-east.yaml`/`values-west.yaml`, the policy is permanently `NonCompliant` on that spoke (`configmaps [trusted-hub-bundle] in namespace imperative is missing, and cannot be created: namespaces "imperative" not found`). Add `imperative: {}` alongside the other spoke namespaces.

### `Kuadrant`/`Authorino`/`Limitador` singleton — one owner only
Keep the cluster-wide `Kuadrant` CR (plus its `Authorino`/`Limitador` CRs) declared in exactly one chart — currently `charts/all/workshop-kuadrant-apis/templates/kuadrant-instance.yaml` (namespace `kuadrant-system`, unconditional). Do NOT add another copy to `neuroface-gateway` or any other chart even if it seems convenient (e.g. gated behind the same `kuadrant.enabled` flag) — the kuadrant-operator deploys the managed Authorino/Limitador into its own install namespace (`redhat-connectivity-link-operator`) regardless of which CR's namespace triggered it, so two declarations just race for the same objects. See the `vp-pattern-dev` skill's "Lessons learned" section for the full incident writeup and the systematic scan technique to catch this class of bug before it ships.

### `Kiali` singleton is also owned externally — don't add a local one
The `servicemesh-config` Application (chart pulled live from `https://charts.validatedpatterns.io`, not vendored) already provisions the cluster-wide `Kiali/default` CR in `istio-system` plus `ClusterRoleBinding/kiali-monitoring-rbac`. Never add a local `Kiali` CR or a `kiali-monitoring-rbac` ClusterRoleBinding to any chart in this repo — it will lose the `cluster_wide_access: true` singleton race every time (Kiali operator hard-errors the loser) and just create ClusterRoleBinding subject-flapping between the two Applications. If you need to customize Kiali's spec, do it through `servicemesh-config`'s `overrides` (`servicemesh.kiali.spec.*`, `servicemesh.kiali.name`, full CRD-passthrough — see the chart's own `templates/kiali.yaml`), not a second CR. Any hardcoded Kiali URL in this repo must resolve to `kiali-istio-system.<domain>` (see `developer-hub.kialiEndpoint` helper), never `kiali-openshift-cluster-observability-operator.<domain>`.

### Backstage `proxy.endpoints` need `allowedHeaders: ['Authorization']` to forward a caller's Bearer token
Backstage's proxy-backend plugin only forwards headers considered "CORS-safe" to the proxy target by default; `Authorization` is excluded unless explicitly allowlisted. If a scaffolder step (or any caller) needs to send a dynamic, per-request `Authorization: Bearer <token>` through `/api/proxy/<endpoint>/...` to the upstream target, that endpoint's config needs `allowedHeaders: ['Authorization']` — otherwise the target receives the request with no auth header at all and returns its own (not Backstage's) 401, which is easy to misdiagnose as a bad/expired token when the token was actually fine. See `charts/all/developer-hub/templates/configmap-app-config-rhdh.yaml`'s `/keycloak` endpoint.

### `--set list[N].field=value` replaces the ENTIRE list, not just index N
`values-hub.yaml`'s `clusterGroup.applications.neuroface-gateway.overrides` sets `kuadrant.realms[0].name`/`kuadrant.realms[0].httpRoute` on top of a chart `values.yaml` that defines `kuadrant.realms` as a *2-element* list. Helm does not merge a `--set`-provided list element-wise with the chart default list -- the override's list (built from whichever indices you touched) replaces the whole thing. So the chart's 2nd realm entry (and any field on it, e.g. a `redirectAuth: false` flag added later) never actually applies live, even though it renders correctly in an isolated `helm template` test that doesn't happen to reproduce every real override. If you need to touch one field on one list element while the app already overrides other fields on that *same* element via array-index `--set`, you must add your own field to that *same* override list (`kuadrant.realms[0].<yourField>=<value>`) -- you cannot rely on the chart's own default list surviving alongside an index-targeted override.
**Corollary when testing live hotfixes**: always pull the *actual* `spec.source.helm.parameters` from the running Application (`oc get application <app> -o jsonpath='{.spec.source.helm.parameters}'`) before `helm template`-and-`oc apply`-ing a fix, and diff it against whatever flags you're about to pass -- an incomplete parameter list can render something that looks right in isolation but silently omits an override like this, and applying it live will overwrite the cluster with a resource ArgoCD's own reconciliation would never actually produce (in this incident: recreating a stray `OIDCPolicy` that broke the main NeuroFace demo's login, since the "real" override collapses to a different single-realm config than the chart's own unoverridden defaults).

### Sprig's `default` treats `0` (and `""`, `false`, `nil`) as empty -- never use it on an intentionally-zero numeric override
`{{ $w.east | default 50 }}` to give a weight a fallback silently turns an explicit `--set gateway.cvWeights.east=0` back into `50`, since Sprig's `default` substitutes whenever the piped value is Go's notion of "empty" -- and `0` counts as empty just like `nil`/`""`/`false` do. Symptom: rendering with the override applied looks completely fine for every field *except* the one you intentionally set to zero, which quietly reverts to the built-in default with no error. Fix: resolve the value explicitly with `hasKey` (`{{- $x := 50 }}{{- if hasKey $dict "key" }}{{- $x = $dict.key }}{{- end }}`) instead of piping through `default` whenever `0`/`false`/`""` are legitimate, intentional values (weights, replica counts, feature-disable flags, etc.) -- not just "unset placeholders".

### `kubernetes.customResources` entries must match what's actually installed and served
RHDH's kubernetes-plugin queries every configured `customResources` GVK for every namespace tied to a Topology-visible entity, regardless of whether that specific entity needs it. Any entry for a CRD/operator this pattern doesn't install by default (Strimzi, Camel K) 404s forever in the Topology view unless gated behind a real `values.yaml` flag (`kafka.enabled`, `camel.enabled` — make sure the flag is a genuine top-level key, not accidentally nested under an unrelated block). Also verify the configured `apiVersion` is actually `served: true` for that CRD (`oc get crd <plural>.<group> -o jsonpath='{range .spec.versions[*]}{.name}: served={.served}{"\n"}{end}'`) — a CRD can list a newer version in its schema without yet serving it, and sibling entries in the same `customResources` block can be on different versions.

### ACM `mustonlyhave` on ArgoCD CR blocks naive `localUsers`/`rbac` patches on spokes
Same risk as documented in `vp-pattern-dev`: patching `ArgoCD` `vp-gitops` with `spec.localUsers` + extended `spec.rbac` (for `argocd-local-users` / MCP) may not stick on east/west because ACM's gitops `ConfigurationPolicy` enforces an exact `spec.rbac` block. Always verify post-sync on all three clusters before wiring downstream consumers (MCP Deployment, token sync Jobs).

### Never let two charts server-side-apply the same field on one singleton CR (ArgoCD included)
On the hub, `charts/all/openshift-gitops` is the **sole chart-side owner** of `ArgoCD/vp-gitops` `spec.localUsers` (toggle: `argocdLocalUser.enabled`) — it deliberately does NOT set `spec.rbac` (see "ArgoCD tuning (hub)" above for why: `patterns-operator` owns that field unconditionally regardless of what any chart sets). `charts/all/argocd-local-users` must only be deployed where `openshift-gitops` chart is *not* also deployed (currently: east/west only). This mirrors the Kuadrant/Kiali "one owner only" rule — Argo CD's SSA for CRs appears to share field-manager identity across Applications, so two charts patching the same field on the same object race silently (no error, just vanishing/truncated fields) even with `ServerSideApply=true` on both.

### Pattern CR `extraParameters` vs Vault paths (MaaS + MCP)

| Parameter / secret | Source | Used by | Reuse spoke token? |
|--------------------|--------|---------|-------------------|
| `spokeCredentials.clusters.east.apiUrl` | Pattern CR extraParameters | acm-hub-spoke, developer-hub, showroom | N/A (URL only) |
| `spokeCredentials.clusters.east.token` | Pattern CR extraParameters | ACM import only | **No** — not for Argo MCP |
| `secret/hub/argocd-mcp-tokens` | Vault + sync Jobs | argocd-mcp ESO | **No** — ai-agent Argo CD tokens |
| `secret/hub/models-as-a-service-db` | values-secret.template | models-as-a-service ESO | N/A |
| `global.hubClusterDomain` | VP operator injection | models-as-a-service hostname, showroom | N/A |

Recommended centralization in `values-global.yaml` (then drop duplicate overrides in `values-hub.yaml`):
```yaml
global:
  workshop:
    userCount: 30
  maas:
    externalHost: maas-rhdp.apps.maas.redhatworkshops.io
    native:
      enabled: true
    authorinoTls: true
  argocdMcp:
    enabled: true
```

Showroom lab namespaces for modules 09/10 (`charts/all/showroom/values.yaml` → `workshopNamespacesHub`): `models-as-a-service`, `argocd-mcp`, `vp-gitops`, `openshift-ingress`. ClusterRole `workshop-lab-reader` includes `maas.opendatahub.io` get/list/watch.

## Porting from hybrid-mesh-platform

When porting charts from hybrid-mesh-platform:
1. Strip Industrial Edge components (disabled in ia-computer-vision)
2. Use VP published charts where available (rhbk, acm, vault, openshift-external-secrets, servicemesh)
3. Use VP `servicemesh` chart with `profile: ambient` on both hub and spokes (not local chart)
4. Keep Skupper spoke interconnect configuration
5. Keep NeuroFace + OVMS/YOLO CV inference charts
6. Remove ApplicationSet-based fleet management (VP Operator handles spoke GitOps)
7. Use `acm-hub-spoke` chart for auto-import with inline spoke tokens via Pattern CR `extraParameters`
