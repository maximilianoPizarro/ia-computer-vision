---
title: Architecture
weight: 30
---

# AI Computer Vision architecture

The AI Computer Vision pattern uses a three-cluster topology.

## Topology

![Architecture diagram](../images/ia-computer-vision/architecture.svg)

## Cluster roles

- **Hub**: Fleet control plane, developer platform, centralized security and secrets.
- **East / West**: Symmetric edge inference clusters; differ only by `clusterName` overrides in Helm values.

## Key integrations

- **ACM** imports spokes using `managedClusterGroups` labels.
- **Skupper** connects application services across cluster boundaries.
- **RHCL / Kuadrant** provides Gateway API ingress with rate limiting and auth policies.
- **OpenShift Service Mesh ambient mode** secures pod-to-pod traffic without sidecars.
- **Thanos + Grafana** federates metrics from hub and spokes.

## Component placement

### Hub cluster

| Component | Purpose |
|---|---|
| ACM | Fleet management; imports east and west spokes |
| Vault + External Secrets Operator | Secrets backing store for GitOps-managed applications |
| ACS Central | Centralized security policy and vulnerability management |
| Red Hat Connectivity Link (RHCL) | Gateway API ingress with 50/50 load balancing to spokes |
| GitLab + Developer Hub | SCM and developer portal with AI Computer Vision software template |
| OpenShift AI | Model serving platform (KServe, workbenches) on the hub |
| Quay + Keycloak | Container registry and OIDC identity provider |

### Spoke clusters (east and west)

| Component | Purpose |
|---|---|
| NeuroFace | Edge AI application with Kafka event streaming |
| OVMS / YOLO CV | Computer vision inference (PPE detection) |
| Skupper (Service Interconnect) | Application-layer connectivity between spokes and hub |
| OpenShift Service Mesh (ambient) | mTLS, telemetry, and L4 metrics without sidecar injection |
| ACS Secured Cluster | Registers spoke with hub ACS Central |
| Observability stack | Grafana, OpenTelemetry, Kiali, Thanos federation |

## Traffic flow

External clients reach NeuroFace through the hub RHCL Gateway. HTTPRoute rules split traffic 50/50 between east and west spokes. Skupper provides secure interconnect for backend services that must communicate across cluster boundaries.
