# Pattern CR examples

Ready-to-apply `Pattern` custom resources for each install scenario.

| File | Scenario | When to use |
|------|----------|-------------|
| [`hub-only-cpu.yaml`](hub-only-cpu.yaml) | **A — Default** | One hub, CPU inference, no pre-installed operators |
| [`hub-spoke-cpu.yaml`](hub-spoke-cpu.yaml) | **B** | Hub + east + west spokes (fill in spoke tokens) |
| [`hub-only-gpu-multi-node.yaml`](hub-only-gpu-multi-node.yaml) | **C** | One hub with GPU workers, fresh cluster |
| [`hub-only-gpu-single-node-preinstalled.yaml`](hub-only-gpu-single-node-preinstalled.yaml) | **D** | Single-node sandbox with operators pre-installed |
| [`spoke.yaml`](spoke.yaml) | **E** | East or west spoke (`clusterGroupName: east` or `west`) |

Full decision table and annotated examples: [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/)

```bash
# Most common install:
oc apply -f examples/pattern-cr/hub-only-cpu.yaml
```
