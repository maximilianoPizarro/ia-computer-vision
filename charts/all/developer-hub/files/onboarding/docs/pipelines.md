# Pipelines and Quay

## Tekton

After your component syncs on the spoke:

1. Open the entity in Developer Hub.
2. Go to the **CI** tab (Tekton plugin).
3. Watch `PipelineRun` for the build.

Pipelines use **buildah** to push images to the internal registry:

```text
quay-registry.<hub-apps-domain>/workshop/<your-unique-name>:latest
```

## Quay UI

- Console menu: **Quay Registry** (hub).
- Or Developer Hub **Quay** tab on the entity (when `quay.io/repository-slug: workshop/<name>` is set).

Images are stored in the shared **`workshop`** organization — one robot account is used for all workshop pushes (simplifies permissions).

## Credentials

The platform creates `quay-workshop-push` in your deployment namespace (from the scaffold manifests). Pipelines reference this secret for push and pull.
