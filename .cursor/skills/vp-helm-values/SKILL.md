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
| 2 | Secrets infrastructure | vault, openshift-external-secrets, rhbk, quay |
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

## Porting from hybrid-mesh-platform

When porting charts from hybrid-mesh-platform:
1. Strip Industrial Edge components (disabled in ia-computer-vision)
2. Use VP published charts where available (rhbk, quay, acm, vault, openshift-external-secrets)
3. Keep ambient mode Service Mesh configuration (local `servicemesh-config` chart)
4. Keep Skupper spoke interconnect configuration
5. Keep NeuroFace + OVMS/YOLO CV inference charts
6. Remove ApplicationSet-based fleet management (VP Operator handles spoke GitOps)
7. Use `acm-hub-spoke` chart for auto-import with Vault-backed spoke tokens
