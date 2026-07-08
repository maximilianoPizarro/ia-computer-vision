# Pattern CR examples

Ready-to-apply `Pattern` custom resources for each install scenario.

Pick **one** file. Do not mix overlays from different scenarios.

| File | Scenario | When to use | `extraValueFiles` |
|------|----------|-------------|-------------------|
| [`hub-only-cpu.yaml`](hub-only-cpu.yaml) | **A — Default** | One hub, CPU inference, no pre-installed operators | `/values-hub-only.yaml` |
| [`hub-spoke-cpu.yaml`](hub-spoke-cpu.yaml) | **B** | Hub + east + west spokes (fill in spoke tokens) | *(none)* |
| [`hub-only-gpu-multi-node.yaml`](hub-only-gpu-multi-node.yaml) | **C** | One hub with GPU workers, fresh cluster | `/values-hub-gpu.yaml`, `/values-hub-only.yaml` |
| [`hub-only-gpu-single-node-preinstalled.yaml`](hub-only-gpu-single-node-preinstalled.yaml) | **D** | Single-node sandbox with operators pre-installed | `/values-hub-gpu.yaml`, `/values-hub-only.yaml`, `/values-hub-single-node.yaml`, `/values-hub-rhpds.yaml` (**rhpds last**) |
| [`spoke.yaml`](spoke.yaml) | **E** | East or west spoke (`clusterGroupName: east` or `west`) | *(none)* |

## Overlay order (important)

Helm replaces each application's `overrides:` list wholesale across composed values files. For Scenario D, `values-hub-rhpds.yaml` must be **last** so it can:

1. Repeat hub-only / single-node overrides for shared apps (`neuroface-gateway`, `developer-hub`, `console-links`)
2. Add RHPDS-specific settings (`ssoHostPrefix`, OperatorGroup skips, `cert-manager.disabled: true`)

Putting `values-hub-only.yaml` after `rhpds` drops `ssoHostPrefix` and reintroduces duplicate OperatorGroups / cert-manager conflicts.

## Quick start

```bash
# Most common install (Scenario A):
oc apply -f examples/pattern-cr/hub-only-cpu.yaml
```

Full decision table and annotated examples: [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/)
