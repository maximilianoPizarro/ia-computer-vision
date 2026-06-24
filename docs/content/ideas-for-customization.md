---
title: Ideas for customization
weight: 40
---

# Ideas for customization

Extend the AI Computer Vision pattern to match your environment.

## Enable Trusted Artifact Signer (optional)

Uncomment the `rhtas`, `rhtpa`, and `cert-manager` subscription entries in `values-hub.yaml` to deploy the Trusted Software Supply Chain components.

## GPU inference on spokes

Add GPU worker nodes and configure `spoke-neuroface-cv` values to use GPU-backed ModelMesh runtimes.

## Custom domain and TLS

Use platform overrides in `overrides/values-AWS.yaml` to enable experimental Let's Encrypt integration for cluster ingress.

## Additional software templates

Extend `charts/all/developer-hub/files/software-templates/` with your organization's Backstage scaffolder templates.

## Single spoke deployment

For proof-of-concept environments, deploy only the hub and one spoke by omitting the west `managedClusterGroup` and skipping west cluster installation.

## Observability backends

Point OpenTelemetry exporters to your existing tracing backend by overriding `charts/all/observability/values.yaml` on each cluster.
