# Pattern CR examples

Ready-to-apply `Pattern` custom resources for each install scenario.

## Default install (copy-paste)

Most common path: **one hub**, CPU inference, no east/west spokes, no pre-installed operators.

1. Install the **Validated Patterns Operator** from OperatorHub.
2. Apply this Pattern CR:

```yaml
apiVersion: gitops.hybrid-cloud-patterns.io/v1alpha1
kind: Pattern
metadata:
  name: ia-computer-vision
  namespace: openshift-operators
spec:
  clusterGroupName: hub
  extraValueFiles:
    - /values-hub-only.yaml
  gitSpec:
    targetRepo: https://github.com/maximilianoPizarro/ia-computer-vision.git
    targetRevision: main
  multiSourceConfig:
    enabled: true
    clusterGroupChartVersion: "0.9.*"
    helmRepoUrl: https://charts.validatedpatterns.io
```

```bash
oc apply -f https://raw.githubusercontent.com/maximilianoPizarro/ia-computer-vision/main/examples/pattern-cr/hub-only-cpu.yaml
```

File on disk: [`hub-only-cpu.yaml`](hub-only-cpu.yaml).

## All scenarios

Pick **one** file. Do not mix overlays from different scenarios.

| File | Scenario | When to use | `extraValueFiles` |
|------|----------|-------------|-------------------|
| [`hub-only-cpu.yaml`](hub-only-cpu.yaml) | **A — Default** | One hub, CPU inference, no pre-installed operators | `/values-hub-only.yaml` |
| [`hub-spoke-cpu.yaml`](hub-spoke-cpu.yaml) | **B** | Hub + east + west spokes (fill in spoke tokens) | *(none)* |
| [`hub-only-gpu-multi-node.yaml`](hub-only-gpu-multi-node.yaml) | **C** | One hub with GPU workers, fresh cluster | `/values-hub-gpu.yaml`, `/values-hub-only.yaml` |
| [`hub-only-gpu-single-node-preinstalled.yaml`](hub-only-gpu-single-node-preinstalled.yaml) | **D** | Single-node sandbox with operators pre-installed | `/values-hub-gpu.yaml`, `/values-hub-only.yaml`, `/values-hub-single-node.yaml`, `/values-hub-rhpds.yaml` (**rhpds last**) |
| [`spoke.yaml`](spoke.yaml) | **E** | East or west spoke (`clusterGroupName: east` or `west`) | *(none)* |
| [`hub-odf-datagrid.yaml`](hub-odf-datagrid.yaml) | **F** | Hub with ODF/MCG S3 + experimental Data Grid RESP (requires Ready ODF; not for Cluster Bot) | `/values-hub-odf-datagrid.yaml` |

## Overlay order (important)

Helm replaces each application's `overrides:` list wholesale across composed values files. For Scenario D, `values-hub-rhpds.yaml` must be **last** so it can:

1. Repeat hub-only / single-node overrides for shared apps (`neuroface-gateway`, `developer-hub`, `console-links`)
2. Add RHPDS-specific settings (`ssoHostPrefix`, OperatorGroup skips, `cert-manager.disabled: true`)

Putting `values-hub-only.yaml` after `rhpds` drops `ssoHostPrefix` and reintroduces duplicate OperatorGroups / cert-manager conflicts.

Full decision table and annotated examples: [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/)
