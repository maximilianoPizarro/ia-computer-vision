# Pipelines and internal registry

Scaffolded NeuroFace projects include a Tekton Pipeline that builds the backend image to the OpenShift internal registry:

```text
image-registry.openshift-image-registry.svc:5000/neuroface-<user>/neuroface-backend:latest
```

## Developer Hub CI tab

When the Tekton plugin is enabled, open your catalog entity → tab **CI** to see pipeline run status. Otherwise use the Kubernetes tab for pod logs.

## Push credentials

Each scaffolded namespace includes a `pipeline` ServiceAccount with `edit` role. OpenShift grants push access to the namespace's internal registry path automatically — no external Quay credentials required.

## Verify a build

```bash
oc get pipelinerun -n neuroface-user1
oc get imagestream -n neuroface-user1
```
