# Documentation screenshot candidates (from demo video)

Source: `c:\Users\Max\Videos\Computer Vision IA VP.mp4` (~47:11, 2026-07-13 cluster-bot install).
Exported under `docs/static/images/ia-computer-vision/`. Browser chrome (tabs/URL bar) cropped; sandbox passwords redacted where present.
**Not wired into `.adoc` yet** — review and approve before inserting `image::` macros.

`:imagesdir:` for pattern docs is `/ia-computer-vision/images/ia-computer-vision` (see `getting-started.adoc`).

| Timestamp | File | What it shows | Suggested `.adoc` section |
|-----------|------|---------------|---------------------------|
| 06:30 | `gs-argocd-hub-syncing.png` | Argo CD app `ia-computer-vision-hub` tree while Progressing / OutOfSync / Syncing | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verifying the hub installation → Step 1: Verify OpenShift GitOps applications |
| 14:00 | `gs-argocd-apps-summary.png` | Argo Applications Summary (~28 apps; mix Synced/OutOfSync, mostly Healthy) | same Step 1 (progress mid-install) |
| 18:07 | `gs-console-app-launcher.png` | OpenShift application launcher — ConsoleLinks to DevSpaces, Grafana, Kiali, Vault | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Step 5 key routes; [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Demo routes |
| 18:22 | `gs-grafana-home.png` | Grafana Home (Welcome / Dashboards entry) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verifying end-to-end / observability; [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) |
| 20:00 | `gs-ocp-cluster-overview.png` | OpenShift console Overview — cluster Healthy, control plane Healthy | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verifying the hub installation (intro) |
| 24:30 | `gs-neuroface-dashboard.png` | NeuroFace hub dashboard (YOLO / PPE ready) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verifying end-to-end operation; also [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Demo routes |
| 25:55 | `gs-kiali-service-overview.png` | Kiali service Overview for `neuroface-backend` (graph loading) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Service Mesh / observability; [architecture.adoc](../../content/patterns/ia-computer-vision/architecture.adoc) |
| 26:00 | `gs-kiali-service-metrics.png` | Kiali Inbound Metrics for `neuroface-backend` | same as above (prefer over overview if only one Kiali shot) |
| 26:20 | `gs-grafana-platform-overview.png` | Grafana dashboard **Platform Overview — Hub-Only** (NeuroFace gateway / CV / Kafka panels) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verifying end-to-end; [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) |
| 29:30 | `gs-workshop-showroom.png` | Showroom Welcome / lab module list (credentials redacted) | [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Showroom lab guide |
| 33:09 | `gs-devspaces-create-workspace.png` | OpenShift Dev Spaces — Create Workspace template gallery | [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Demo routes / DevSpaces; [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Step 5 key routes |
| 33:00 | `gs-openshift-ai-home.png` | OpenShift AI home with `maas-workshop` project | [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Module 09 Native MaaS; [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Step 5 key routes |
| 35:00 | `gs-developer-hub-home.png` | Developer Hub Home — catalog cards + OIDC / API key scaffolder templates | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Step 5b software template; [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Demo routes / OIDC |
| 37:00 | `gs-developer-hub-cv-api-overview.png` | Catalog Overview for Computer Vision API (AuthPolicy / realm-cv JWT description) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Test inference / AuthPolicy 401 section; [architecture.adoc](../../content/patterns/ia-computer-vision/architecture.adoc) — RHCL AuthPolicy |
| 38:45 | `gs-console-plugins-kuadrant.png` | Cluster Settings → Console plugins — `kuadrant-console-plugin` **Disabled** | [troubleshooting.adoc](../../content/patterns/ia-computer-vision/troubleshooting.adoc) (Connectivity Link console) or skill note; optional getting-started post-install |
| 41:45 | `gs-connectivity-link-overview.png` | Connectivity Link Overview — 6 gateways Healthy / Enforced | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Verify RHCL Gateway and HTTPRoute |
| 42:00 | `gs-api-product-cv-definition.png` | API Product `neuroface-cv-openapi` Definition (OIDC / Authorize) | [getting-started.adoc](../../content/patterns/ia-computer-vision/getting-started.adoc) — Test inference through the hub gateway |
| 43:30 | `ts-cv-health-unauthenticated-200.png` | Swagger Try-it-out `GET /health` → **200 without token** (AuthPolicy not enforced) | [troubleshooting.adoc](../../content/patterns/ia-computer-vision/troubleshooting.adoc) — AuthPolicy / MissingDependency (expected 401 is broken here) |
| 45:00 | `gs-connectivity-link-policy-topology.png` | Policy Topology graph (AuthPolicy / Gateway / HTTPRoute) | [architecture.adoc](../../content/patterns/ia-computer-vision/architecture.adoc) — RHCL / Gateway API; troubleshooting AuthPolicy |
| 46:00 | `gs-developer-hub-maas-openapi.png` | MaaS OpenAPI `GET /v1/models` (401 documented for missing APIKEY) | [workshop.adoc](../../content/patterns/ia-computer-vision/workshop.adoc) — Module 09 / MaaS API Key |

## Notes for editors

- Ephemeral Cluster Bot hostname (`ci-ln-st7wvsb-…`) appears in several UIs; keep screenshots as-is or re-capture on a branded environment later.
- Preferred AuthPolicy demo still missing from this set: a clear **401** without Bearer token. Use `ts-cv-health-unauthenticated-200.png` only in troubleshooting until the fix is verified.
- PPE webcam frames were skipped (user face in frame).
- **Vault UI was never the active browser tab** in this recording (only an open background tab + ConsoleLink in `gs-console-app-launcher.png`). Re-capture Vault secrets UI / login on the next cluster if you need a dedicated Vault figure.
- Temporary frame cache for this extraction lived under `.tmp-video-frames/` (local only; safe to delete).

## Suggested AsciiDoc insert (after approval)

```asciidoc
image::gs-developer-hub-home.png[Red Hat Developer Hub home with Computer Vision and MaaS catalog templates,align=center,width=80%]
```
