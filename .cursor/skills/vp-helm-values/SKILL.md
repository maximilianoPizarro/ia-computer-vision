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
| 0 | Platform base | openshift-gitops, platform-users |
| 1 | Operators + ACM | observability, acm |
| 2 | Secrets infrastructure | vault, openshift-external-secrets, rhbk |
| 3 | Developer tools | gitlab-operator |
| 4 | Developer portal | developer-hub |
| 5 | AI + workshop | openshift-ai-hub, showroom |
| 6 | Multi-cluster | neuroface-gateway, acm-hub-spoke |
| 7 | Security + IDE | acs-init-bundle-sync, devspaces |
| 10 | Console UI | console-links |

### Spoke sync waves
| Wave | Purpose | Applications |
|------|---------|-------------|
| 0 | Platform base | openshift-gitops, platform-users |
| 1 | Service Mesh + ESO | servicemesh-config, openshift-external-secrets |
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

## ArgoCD tuning (hub)

The `openshift-gitops` chart patches the ArgoCD CR:

```yaml
spec:
  controller:
    resources:
      limits: { cpu: "4", memory: 12Gi }
      requests: { cpu: "1", memory: 6Gi }
    processors:
      operation: 25
      status: 50
    env:
      - name: ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT
        value: "20"
  resourceExclusions: |
    - apiGroups: [tekton.dev]
      kinds: [TaskRun, PipelineRun]
    - apiGroups: [clusterview.open-cluster-management.io]
      kinds: ['*']
    - apiGroups: [internal.open-cluster-management.io]
      kinds: ['*']
```

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

## Porting from hybrid-mesh-platform

When porting charts from hybrid-mesh-platform:
1. Strip Industrial Edge components (disabled in ia-computer-vision)
2. Use VP published charts where available (rhbk, acm, vault, openshift-external-secrets, servicemesh)
3. Use VP `servicemesh` chart with `profile: ambient` on both hub and spokes (not local chart)
4. Keep Skupper spoke interconnect configuration
5. Keep NeuroFace + OVMS/YOLO CV inference charts
6. Remove ApplicationSet-based fleet management (VP Operator handles spoke GitOps)
7. Use `acm-hub-spoke` chart for auto-import with inline spoke tokens via Pattern CR `extraParameters`
