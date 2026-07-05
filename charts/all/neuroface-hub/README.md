# neuroface-hub

Hub-local NeuroFace **chat** demo for hub-only installs (no east/west spokes).

## Why this exists

`charts/all/neuroface-gateway` load-balances the main NeuroFace demo across
`neuroface-app-{east,west}` backends reachable via Skupper -- on a hub-only
install (`values-hub-only.yaml`) those spokes don't exist, so it renders no
route at all. `charts/all/spoke-neuroface` (the full stack: chat + OVMS face
detection + YOLO PPE + Kafka) is designed to run **on** a spoke, connected
back to the hub over Skupper -- it can't run standalone on the hub either.

This chart deploys just the **chat** component of the same upstream
[neuroface](https://github.com/maximilianoPizarro/neuroface) chart, wired
directly to a model already served on the hub (defaults to the GPU vLLM
`InferenceService` from `values-hub-gpu.yaml`). Face detection (OVMS) and
PPE/Kafka stay disabled -- there's no hub-local camera feed or PPE model
to back them without a spoke.

## Configuration

Override `neuroface.chat.modelEndpoint` / `modelName` to point at any other
OpenAI-compatible endpoint already running on the hub, e.g. native MaaS:

```yaml
neuroface:
  chat:
    modelEndpoint: "http://qwen2-5-coder-7b-instruct-predictor.gpu-models.svc.cluster.local:8080"
    modelName: "qwen2-5-coder-7b-instruct"
```

## Access

```bash
oc get route neuroface -n neuroface-hub -o jsonpath='{.spec.host}'
```
