# AI Computer Vision

[![GitHub Pages](https://github.com/maximilianoPizarro/ia-computer-vision/actions/workflows/pages.yml/badge.svg)](https://github.com/maximilianoPizarro/ia-computer-vision/actions/workflows/pages.yml)
![Tier: Sandbox](https://img.shields.io/badge/tier-sandbox-yellow)
![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue)
![OpenShift 4.20+](https://img.shields.io/badge/OpenShift-4.20%2B-red)

Multi-cluster AI Computer Vision at the edge using Red Hat OpenShift, Validated Patterns GitOps, and hub-spoke fleet management.

**Full documentation:** [https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/)

## Business problem

Organizations deploying AI computer vision at distributed edge sites need:

- Consistent, auditable deployment of inference workloads across regions
- Secure connectivity between edge clusters and a central control plane
- Centralized observability, security policy, and developer self-service
- GitOps-driven lifecycle management without manual cluster configuration

## Solution

The **AI Computer Vision** Validated Pattern supports two deployment topologies:

| Topology | Clusters | Pattern CR |
|----------|----------|------------|
| **Hub-only CPU** (default) | 1 hub | [`examples/pattern-cr/hub-only-cpu.yaml`](examples/pattern-cr/hub-only-cpu.yaml) |
| **Hub + spokes** | hub + east + west | [`examples/pattern-cr/hub-spoke-cpu.yaml`](examples/pattern-cr/hub-spoke-cpu.yaml) + [`spoke.yaml`](examples/pattern-cr/spoke.yaml) |

See the [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/) for GPU and single-node sandbox variants.

### Hub-only (one cluster)

| Cluster | Role | Key components |
|---------|------|----------------|
| **Hub** | All-in-one platform | ACM (local), Vault, ESO, RHCL gateway, GitLab, Developer Hub, OpenShift AI, Keycloak, NeuroFace + YOLO CV (local), Kafka |

### Hub + spokes (three clusters)

| Cluster | Role | Key components |
|---------|------|----------------|
| **Hub** | Fleet control plane | ACM, Vault, ESO, ACS Central, RHCL gateway, GitLab, Developer Hub, OpenShift AI, Keycloak |
| **East spoke** | Edge inference | NeuroFace, OVMS/YOLO CV, Skupper, Service Mesh ambient, ACS Secured, observability |
| **West spoke** | Edge inference | Same as east (load-balanced via RHCL 50/50 HTTPRoute) |

Install with the Validated Patterns Operator (`oc apply -f examples/pattern-cr/...`) or `./pattern.sh make install`, specifying `clusterGroupName: hub`, `east`, or `west`.

## What you will deploy

After a full installation you obtain:

- **Multi-cluster fleet management** — RHACM 2.16 registers east and west as managed clusters with GitOps-driven configuration
- **Centralized secrets** — Vault with ESO backing GitLab, Keycloak, Developer Hub, and application secrets
- **Unified security** — RHACS Central on the hub with Secured Cluster sensors on every spoke
- **External inference gateway** — RHCL HTTPRoute with 50/50 load balancing to east and west NeuroFace backends
- **Edge computer vision** — NeuroFace application with OVMS/YOLO PPE detection on each spoke
- **Cross-cluster connectivity** — Skupper Service Interconnect linking hub and spoke services
- **Service mesh telemetry** — OpenShift Service Mesh 3.2 ambient mode without sidecar injection
- **Developer platform** — GitLab, Developer Hub (AI CV software template, Red Hat Developer Lightspeed, OpenShift DevSpaces), Keycloak
- **AI platform** — OpenShift AI 3.4 with native **Models as a Service** (Gen AI Studio, MaaS gateway) plus Kuadrant **AI Gateway** as a parallel proxy path
- **GitOps MCP** — `mcp-for-argocd` on the hub for multi-cluster Argo CD queries (OpenShift Lightspeed client)
- **Observability** — Grafana, OpenTelemetry, Kiali, and Thanos federation across clusters
- **Workshop mode (default)** — 30 HTPasswd users, Showroom lab guide with embedded terminal

## Product version matrix

| Product | Version | Channel | Purpose |
|---------|---------|---------|---------|
| Red Hat OpenShift Container Platform | 4.20+ | — | Platform for hub and spoke clusters |
| Red Hat Advanced Cluster Management | 2.16 | `release-2.16` | Fleet management and spoke import |
| Red Hat OpenShift GitOps | — | — | GitOps reconciliation (installed by VP Operator) |
| Red Hat Advanced Cluster Security | 4.x | `stable` | Central + Secured Cluster security |
| Red Hat Connectivity Link | — | `stable` | Gateway API ingress and Kuadrant policies |
| Red Hat OpenShift AI | 3.4 | `stable-3.4` | Model serving and data science platform |
| Red Hat OpenShift Service Mesh | 3.2 | `stable-3.2` | Ambient mesh mTLS and telemetry |
| Red Hat Developer Hub | — | `fast` | Developer portal and scaffolder |
| Red Hat Build of Keycloak | 26.4 | `stable-v26.4` | OIDC identity provider + per-user biometric RHBK |
| GitLab Operator | — | `stable` | Source control and CI/CD |
| OpenShift Pipelines | — | `latest` | CI/CD pipelines on hub |
| OpenShift DevSpaces | — | `stable` | Cloud IDE workspaces |
| External Secrets Operator | 1.x | `stable-v1` | Vault-to-Kubernetes secret sync |
| Skupper | 2.x | `stable-2` | Cross-cluster application connectivity |
| Cluster Observability Operator | — | `stable` | Grafana and monitoring CRDs |
| OpenTelemetry | — | `stable` | Distributed tracing collectors |
| AMQ Streams | — | `stable` | Event streaming on spokes |

Channels reflect `values-hub.yaml` and `values-east.yaml` subscription definitions.

## Architecture

![Hub-spoke architecture diagram](docs/static/images/ia-computer-vision/architecture-hub-spoke.png)

![Inference traffic flow](docs/static/images/ia-computer-vision/inference-traffic-flow.png)

```mermaid
flowchart TB
  subgraph hub ["Hub cluster"]
    ACM[ACM]
    Vault[Vault + ESO]
    RHDH[Developer Hub + Lightspeed]
    RHOAI[OpenShift AI]
    RHCL[AI Gateway / RHCL]
    ACS_C[ACS Central]
  end

  subgraph east ["East spoke"]
    NF_E[NeuroFace]
    CV_E[OVMS / YOLO CV]
    SK_E[Skupper]
    SM_E[Service Mesh ambient]
    ACS_E[ACS Secured]
  end

  subgraph west ["West spoke"]
    NF_W[NeuroFace]
    CV_W[OVMS / YOLO CV]
    SK_W[Skupper]
    SM_W[Service Mesh ambient]
    ACS_W[ACS Secured]
  end

  Git[(ia-computer-vision Git repo)] --> hub
  Git --> east
  Git --> west
  ACM --> east
  ACM --> west
  RHCL --> NF_E
  RHCL --> NF_W
  RHDH -->|"APIKEY"| RHCL
  NF_E -->|"APIKEY"| RHCL
  NF_W -->|"APIKEY"| RHCL
  RHCL -->|"Bearer Token"| MaaS[(MaaS RHDP)]
  SK_E --- SK_W
  ACS_C --> ACS_E
  ACS_C --> ACS_W
```

## Prerequisites

- Red Hat OpenShift Container Platform 4.20+ with the Validated Patterns Operator installed
- **Hub-only (most common):** one hub cluster — 3× `m6a.2xlarge` control plane + **4–5× `m6a.4xlarge` workers**
- **Hub + spokes:** three clusters (hub, east, west) — hub with 3× `m6a.4xlarge` workers; spokes with 3× `m6a.2xlarge` workers ([cluster sizing](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/cluster-sizing/))
- `podman` and cluster admin `kubeconfig` for CLI install
- Image builds use the OpenShift internal registry (no external Quay required)

## Quick start

**Pick your topology first** — see the [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/) for the full decision table. Ready-to-apply YAML files are in [`examples/pattern-cr/`](examples/pattern-cr/).

### Hub-only CPU (default — one cluster)

Most common install: one hub, CPU inference, no east/west spokes.

```bash
oc apply -f examples/pattern-cr/hub-only-cpu.yaml
```

Or via CLI:

```bash
EXTRA_HELM_OPTS='-f values-hub-only.yaml' ./pattern.sh make install
```

### Hub + east + west spokes (three clusters)

Install east and west spokes first, then the hub last. This allows automatic RHACM spoke import via Vault tokens.

#### 1. East spoke

```bash
export TARGET_CLUSTERGROUP=east
./pattern.sh make install
```

#### 2. West spoke

```bash
export TARGET_CLUSTERGROUP=west
./pattern.sh make install
```

#### 3. Collect spoke tokens

The pattern automatically creates a `acm-import` ServiceAccount with `cluster-admin` in `kube-system` on each spoke (via the `platform-users` chart at wave 0). You only need to generate the token:

```bash
# On each spoke — generate a long-lived token (SA is created by the pattern)
oc create token -n kube-system acm-import --duration=87600h
oc whoami --show-server
```

Add the tokens to `~/values-secret-ia-computer-vision.yaml` under `spoke-credentials`.

#### 4. Hub cluster

```bash
./pattern.sh make install
# Uses values-global.yaml (clusterGroupName: hub)
```

Apply [`examples/pattern-cr/hub-spoke-cpu.yaml`](examples/pattern-cr/hub-spoke-cpu.yaml) (fill in spoke tokens from step 3) or create the Pattern CR from the OCP Console.

For spokes, use [`examples/pattern-cr/spoke.yaml`](examples/pattern-cr/spoke.yaml) with `clusterGroupName: east` or `west`.

### Other topologies

| Scenario | File |
|----------|------|
| Hub-only GPU, multi-node | [`hub-only-gpu-multi-node.yaml`](examples/pattern-cr/hub-only-gpu-multi-node.yaml) |
| Hub-only GPU, single-node with pre-installed operators | [`hub-only-gpu-single-node-preinstalled.yaml`](examples/pattern-cr/hub-only-gpu-single-node-preinstalled.yaml) |

See the [Pattern CR guide](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/) for details on GPU sandboxes (including `maxPods` and `values-hub-gpu-minimal.yaml`).

## Secrets

### Option A — CLI install (`./pattern.sh make install`)

Copy the template and run the install. Secrets with `onMissingValue: generate` are auto-generated in Vault:

```bash
cp values-secret.yaml.template ~/values-secret-ia-computer-vision.yaml
# Edit ~/values-secret-ia-computer-vision.yaml to fill in spoke tokens and optional keys
./pattern.sh make install
```

### Option B — Console install (Pattern CR)

When you install via the OCP console, `make load-secrets` does not run. The `vault-secrets-bootstrap` chart (wave 3, hub only) automatically seeds `secret/hub/*` in Vault after Vault and ESO are ready — no manual steps required for a standard install.

If bootstrap was skipped or failed, load secrets manually after Vault initializes (wave 2):

```bash
# Generate passwords and load into Vault
oc exec vault-0 -n vault -- vault kv put secret/hub/gitlab-credentials \
  root-password="$(openssl rand -base64 16)" runner-token="$(openssl rand -base64 16)"

oc exec vault-0 -n vault -- vault kv put secret/hub/rhbk-credentials \
  admin-password="$(openssl rand -base64 16)" db-password="$(openssl rand -base64 16)"

oc exec vault-0 -n vault -- vault kv put secret/hub/developer-hub-secrets \
  oidc-client-secret="$(openssl rand -base64 24)" \
  session-secret="$(openssl rand -base64 32)" \
  gitlab-token="<GITLAB_PAT>"

oc exec vault-0 -n vault -- vault kv put secret/hub/ai-gateway-platform-keys \
  platformApiKey="$(openssl rand -base64 32)"

oc exec vault-0 -n vault -- vault kv put secret/hub/workshop-registration \
  adminToken="$(openssl rand -base64 24)"

oc exec vault-0 -n vault -- vault kv put secret/hub/minio-credentials \
  accesskey="$(openssl rand -base64 16)" secretkey="$(openssl rand -base64 24)"

# rhbk-iam reads ONE Vault secret per user per realm (not a single combined
# object) -- repeat for every user up to userCount, for each of the three
# realms (neuroface, maas, cv):
for realm in neuroface maas cv; do
  for i in $(seq 1 30); do
    oc exec vault-0 -n vault -- vault kv put "secret/hub/keycloak/realms/${realm}/user${i}" \
      clientSecret="$(openssl rand -base64 24)"
  done
done

oc exec vault-0 -n vault -- vault kv put secret/hub/keycloak/realms/cv/backstage-provisioner \
  clientSecret="$(openssl rand -base64 24)"
```

| Secret | Fields | Required | Used by |
|--------|--------|----------|---------|
| `gitlab-credentials` | `root-password`, `runner-token` | Auto-generated | GitLab admin, CI runner |
| `rhbk-credentials` | `admin-password`, `db-password` | Auto-generated | Keycloak admin, PostgreSQL |
| `developer-hub-secrets` | `oidc-client-secret`, `session-secret`, `gitlab-token` | `oidc-client-secret` and `session-secret` auto-generated; `gitlab-token` set after GitLab deploys | RHDH OIDC, session, scaffolder |
| `ai-gateway-platform-keys` | `platformApiKey` | Auto-generated | Kuadrant API key for AI Gateway (used by Lightspeed and NeuroFace chat) |
| `workshop-registration` | `adminToken` | Auto-generated | Workshop self-registration app (Showroom) |
| `minio-credentials` | `accesskey`, `secretkey` | Auto-generated | NeuroFace CV model storage (overridden by GitLab's bundled Minio on spokes, see below) |
| `keycloak/realms/{neuroface,maas,cv}/user{N}` | `clientSecret` (one path per user per realm, `N` up to `userCount`) | Auto-generated | Per-user Keycloak client secrets (`rhbk-iam` realms) |
| `keycloak/realms/cv/backstage-provisioner` | `clientSecret` | Auto-generated | Developer Hub Keycloak Admin REST provisioner (OIDC credentials self-service template) |
| `spoke-credentials` | `east-token`, `east-api-url`, `west-token`, `west-api-url` | Via Pattern CR `extraParameters` (inline mode) | ACM auto-import |

See [Validated Patterns secrets management](https://validatedpatterns.io/learn/secrets-management-in-the-validated-patterns-framework/).

## Workshop mode

Workshop mode is enabled by default with 30 pre-provisioned users (`user1`–`user30`, password `Welcome123!`) and a Showroom lab guide on the hub cluster.

| Component | Purpose |
|-----------|---------|
| `platform-users` | HTPasswd OAuth users + console RBAC (hub and spokes) |
| `developer-hub` / `gitlab-operator` / `devspaces` | Per-user Developer Hub, GitLab, and DevSpaces access |
| `showroom` | Antora lab guide with embedded `oc` terminal |

Access Showroom at `https://showroom-showroom.apps.<hub_domain>`. You can also [preview the workshop guide online](https://maximilianopizarro.github.io/ia-computer-vision-pages/modules/main/index.html) to see how the lab environment looks.

To change the number of users, update the `userCount` override in `values-hub.yaml`, `values-east.yaml`, and `values-west.yaml`. See [Workshop mode documentation](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/workshop/).

## Documentation

| Topic | Link |
|-------|------|
| Pattern overview | [Documentation home](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/) |
| **Pattern CR guide** | [Which CR to apply per topology](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/pattern-cr-guide/) |
| Getting started | [Install and verify](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/getting-started/) |
| Cluster sizing | [Instance types and worker count](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/cluster-sizing/) |
| Architecture | [Topology and traffic flow](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/architecture/) |
| Scaffolding and secrets | [Software template and Vault/ESO flows](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/scaffolding-and-secrets/) |
| Troubleshooting | [Common issues](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/troubleshooting/) |
| Customization | [Extension ideas](https://maximilianopizarro.github.io/ia-computer-vision/patterns/ia-computer-vision/ideas-for-customization/) |

Local preview:

```bash
cd docs && make serve
```

## Maintainer

**Maximiliano Pizarro** — Specialist Solution Architect — [mapizarr@redhat.com](mailto:mapizarr@redhat.com)

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Support

See [SUPPORT.md](SUPPORT.md).
