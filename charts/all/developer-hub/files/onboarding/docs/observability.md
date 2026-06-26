# Observability and consoles

## From Developer Hub

- **Overview** — OCM cluster cards (hub, east, west) when `plugins.ocm.enabled` is true. Sidebar **Clusters** (`/ocm`).
- **Kubernetes** — workloads on the spoke selected in entity annotations.
- **Topology** — mesh-aware graph when `backstage.io/kubernetes-cluster` is set.
- **Kiali** — sidebar **Kiali** (`/kiali`) and entity **Kiali** tab when the component has `backstage.io/kubernetes-namespace` (e.g. `neuroface-backend`, `workshop-apis-gateway`).

Use the OpenShift console Kiali link for full multi-cluster mesh admin; the Developer Hub tab focuses on the namespace tied to the catalog entity.

## Plugin catalog

System **rhdh-platform-plugins** in the Developer Hub catalog lists installed dynamic plugins (OCM, Kiali, Tekton, Topology, Kuadrant, Argo CD).

## OpenShift console (hub)

With **cluster-reader**, use the **Platform Hub-Spoke** application menu:

| Link | Purpose |
|------|---------|
| ACM Clusters | Multicluster inventory |
| Kiali Service Mesh | Hub mesh console |
| Skupper Console | Service interconnect topology |
| Grafana Dashboards | Platform metrics |
| ACS Central | Vulnerability and policy |
| GitLab | Source repos |
| Quay Registry | Container images |

## Spoke consoles

Kiali/Grafana links on spokes use the spoke apps domain (see console links deployed on each cluster).

## ACS in Developer Hub

Entities with container images may show security data when the ACS / Security Insights plugin is enabled and Central is reachable from Developer Hub.
