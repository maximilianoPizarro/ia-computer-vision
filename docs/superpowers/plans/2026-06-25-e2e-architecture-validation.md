# E2E Architecture & Demo Validation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to run this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate de punta a punta el patrón AI Computer Vision (hub + east + west): arquitectura, journey CV, valor de Developer Hub (self-service + keys MaaS), OpenShift AI para imágenes, y observabilidad OTel/Grafana — alineado con los cambios recientes del repo.

**Architecture:** Hub-spoke con RHACM, Vault/ESO, RHDH+RHBK, GitLab, RHCL gateway, Skupper, NeuroFace/OVMS en spokes, Kafka→Mailpit (east), Grafana/Thanos/OTel multi-cluster.

**Tech Stack:** OCP 4.20+, RHACM 2.16, RHOAI 3.4, RHBK 26.4, RHDH, Skupper 2.x, OSSM 3.2 ambient, OpenTelemetry, Grafana Operator, Validated Patterns GitOps.

**Baseline de cambios recientes a verificar:**

| Cambio | Archivos clave |
|--------|----------------|
| Quay removido → registry interno | `values-hub.yaml`, skeleton Tekton |
| Scaffolding per-user NeuroFace + RHBK | `ai-cv-skeleton/`, `applicationset-user-neuroface.yaml` |
| Kafka→Mailpit PPE alerts | `charts/all/mailpit/`, `hub-interconnect/listener-kafka-east-tst.yaml` |
| OIDC/SSO automatizado | `route-sso.yaml`, `keycloak-realm.yaml`, `externalsecret-*-oidc*.yaml` |
| Console links (Skupper Observer, etc.) | `charts/all/console-links/`, `skupper-network-observer/` |
| PPE Kafka solo east | `values-west.yaml` → `neuroface.ppe.kafka.enabled: false` |

---

## Variables de entorno (completar al inicio)

```bash
export HUB_DOMAIN="apps.<hub>.<domain>"          # ej. apps.cluster-name.example.com
export EAST_DOMAIN="apps.<east>.<domain>"
export WEST_DOMAIN="apps.<west>.<domain>"
export HUB_API="https://api.<hub>.<domain>:6443"
export VP_NS="vp-gitops"
export DEMO_USER="user1"
export DEMO_PASS="Welcome123!"
```

---

## Task 0: Pre-flight — salud del patrón

**Files:** `values-hub.yaml`, `values-east.yaml`, `values-west.yaml`, `values-secret.yaml.template`

- [ ] **Step 1: Login hub y verificar parent app**

```bash
oc login --token=<token> --server=$HUB_API --insecure-skip-tls-verify
oc get application -n $VP_NS | grep -E 'ia-computer-vision|NAME'
oc get application ia-computer-vision-hub -n $VP_NS -o jsonpath='{.status.health.status}{"\n"}{.status.sync.status}{"\n"}'
```

Expected: `Healthy` / `Synced` (parent puede estar Degraded si un hijo falla — anotar cuál).

- [ ] **Step 2: Apps críticas hub**

```bash
for app in vault rhbk developer-hub gitlab-operator openshift-ai-hub mailpit \
  hub-interconnect skupper-network-observer neuroface-gateway observability console-links showroom; do
  printf "%-28s " "$app"
  oc get application "$app" -n $VP_NS -o jsonpath='{.status.health.status}/{.status.sync.status}{"\n"}' 2>/dev/null || echo "MISSING"
done
```

Expected: todas `Healthy/Synced` o lista de excepciones documentadas.

- [ ] **Step 3: Spokes en ACM**

```bash
oc get managedcluster | grep -E 'east|west|NAME'
```

Expected: `True` en Available para east y west.

- [ ] **Step 4: Vault secrets mínimos**

```bash
oc exec vault-0 -n vault -- vault kv get secret/hub/rhbk-credentials 2>/dev/null | grep -E 'admin-password|db-password'
oc exec vault-0 -n vault -- vault kv get secret/hub/developer-hub-secrets 2>/dev/null | grep -E 'oidc-client-secret|session-secret'
```

Expected: tres keys presentes. Si falta `oidc-client-secret`:

```bash
oc exec vault-0 -n vault -- vault kv patch secret/hub/developer-hub-secrets \
  oidc-client-secret="$(openssl rand -base64 24)"
oc annotate externalsecret -n developer-hub developer-hub-oidc-auth force-sync=$(date +%s) --overwrite
oc annotate externalsecret -n keycloak-system developer-hub-oidc-client force-sync=$(date +%s) --overwrite
```

- [ ] **Step 5: OIDC discovery (bloqueante para RHDH)**

```bash
curl -sk -o /dev/null -w '%{http_code}\n' \
  "https://sso.${HUB_DOMAIN#apps.}/realms/backstage/.well-known/openid-configuration"
```

Expected: `200`. Si `503`: revisar `oc get route -n keycloak-system` y sync app `developer-hub`.

---

## Task 1: Capa GitOps & fleet

**Files:** `charts/all/acm-hub-spoke/`, `charts/all/openshift-gitops/`, `values-hub.yaml`

- [ ] **Step 1: Argo CD recursos hub**

```bash
oc get pods -n openshift-gitops | grep -v Completed
oc get application -n $VP_NS --no-headers | awk '$3!="Healthy" || $4!="Synced" {print}'
```

- [ ] **Step 2: ESO ClusterSecretStore**

```bash
oc get clustersecretstore vault-backend -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
oc get externalsecret -A | grep -v SecretSynced
```

Expected: `True`; sin ExternalSecrets stuck.

- [ ] **Step 3: platform-users (workshop)**

```bash
oc get oauth workshop-users -n openshift-config 2>/dev/null || oc get secret htpasswd-users -n openshift-gitops 2>/dev/null
```

Login manual: consola hub → **workshop-users** → `$DEMO_USER` / `$DEMO_PASS`.

- [ ] **Step 4: Documentar sign-off Task 1**

| Check | Pass |
|-------|------|
| Parent + apps críticas | ☐ |
| ACM east/west Ready | ☐ |
| Vault + ESO | ☐ |
| OIDC 200 | ☐ |
| Login consola workshop-users | ☐ |

---

## Task 2: Capa conectividad & mesh

**Files:** `charts/all/hub-interconnect/`, `charts/all/spoke-interconnect/`, `charts/all/neuroface-gateway/`, `charts/all/skupper-network-observer/`

- [ ] **Step 1: Skupper sites**

```bash
oc get site -n service-interconnect 2>/dev/null
oc login --token=<east-token> --server=<east-api> --insecure-skip-tls-verify
oc get site -n service-interconnect
```

Expected (hub): `STATUS=Ready`, `SITES IN NETWORK=3` (hub + east + west).

- [ ] **Step 1b: Skupper spoke auto-link (`accesstoken-sync`)**

Run on hub after `hub-interconnect` and `acm-hub-spoke` are synced:

```bash
oc get accessgrant spoke-link -n service-interconnect -o jsonpath='{.status.code}{"\n"}'
oc get cronjob skupper-accesstoken-sync -n service-interconnect
oc get job -n service-interconnect | grep accesstoken
oc logs job/skupper-accesstoken-sync-hook -n service-interconnect --tail=50
oc get managedclusterview skupper-hub-link-status -n east -o jsonpath='{.status.result.status.status}{"\n"}'
oc get managedclusterview skupper-hub-link-status -n west -o jsonpath='{.status.result.status.status}{"\n"}'
```

Expected:
- `AccessGrant/spoke-link` status has `code`, `url`, `ca`
- PostSync job `skupper-accesstoken-sync-hook` completes with `All spoke Skupper links Ready`
- ManagedClusterView link status `Ready` on `east` and `west`

If the PostSync job failed before ACM imported spokes, wait for the CronJob (every 30 min) or delete the job and re-sync `hub-interconnect`.

- [ ] **Step 2: Skupper Network Observer (console link)**

Abrir desde consola hub: **Skupper Console (Network)**  
URL esperada: `https://skupper-network-observer-service-interconnect.<domain-base>`

```bash
curl -sk -o /dev/null -w '%{http_code}\n' \
  "https://skupper-network-observer-service-interconnect.${HUB_DOMAIN#apps.}/"
```

Expected: `200` o `302`.

- [ ] **Step 3: RHCL Gateway hub**

```bash
oc login --token=<hub-token> --server=$HUB_API --insecure-skip-tls-verify
oc get gateway -n neuroface-gateway-system
oc get httproute -n neuroface-gateway-system
oc get route neuroface-gateway -n neuroface-gateway-system -o jsonpath='{.spec.host}{"\n"}'
```

Expected: hosts `neuroface.$HUB_DOMAIN`, `neuroface-cv.$HUB_DOMAIN`.

- [ ] **Step 4: Spoke gateway per-user**

```bash
oc login --token=<east-token> --server=<east-api> --insecure-skip-tls-verify
oc get route neuroface-spoke-gateway -n neuroface -o jsonpath='{.spec.host}{"\n"}'
oc get gateway -n neuroface
```

- [ ] **Step 5: Kiali**

Abrir: `https://kiali-openshift-cluster-observability-operator.$HUB_DOMAIN`

Expected: mesh graph carga; namespaces `istio-system`, `neuroface`, `neuroface-gateway-system` visibles.

---

## Task 3: Developer Hub — portal self-service (soluciones)

**Files:** `charts/all/developer-hub/`, `ai-computer-vision.yaml`, `ai-cv-skeleton/`

- [ ] **Step 1: Login RHDH**

URL: `https://developer-hub.$HUB_DOMAIN`  
Credenciales: `$DEMO_USER` / `$DEMO_PASS` (realm `backstage` vía SSO).

- [ ] **Step 2: Catálogo y template**

En RHDH verificar:

- [ ] Entidad sistema NeuroFace / NeuroFace CV visible
- [ ] Template **AI Computer Vision at the Edge** en Create
- [ ] Usuario `$DEMO_USER` en catálogo (group `developers`)

- [ ] **Step 3: Ejecutar scaffold (journey core)**

1. Create → **AI Computer Vision at the Edge**
2. Owner: `$DEMO_USER`, Spoke: **east**
3. Hub domain / spoke domain: valores reales del cluster
4. Submit

Expected:

```bash
# Tras ~2-5 min en hub GitLab
curl -sk -o /dev/null -w '%{http_code}\n' \
  "https://gitlab.apps.${HUB_DOMAIN#apps.}/ws-workshop/neuroface-${DEMO_USER}"

# En spoke east
oc get applicationset -n $VP_NS user-neuroface-apps
oc get application -n $VP_NS | grep "neuroface-${DEMO_USER}"
```

- [ ] **Step 4: Validar despliegue per-user**

```bash
oc get pods,httproute,route -n "neuroface-${DEMO_USER}" 2>/dev/null || oc get ns | grep neuroface
curl -sk -o /dev/null -w '%{http_code}\n' \
  "https://neuroface-spoke-gateway.${EAST_DOMAIN#apps.}/user/${DEMO_USER}/"
```

Expected: pods Running; HTTP `200`/`302`.

- [ ] **Step 5: API docs & DevSpaces links**

En entidad catálogo `neuroface-$DEMO_USER`:

- [ ] Tab **API** → OpenAPI Try it Out responde
- [ ] Link **Open in DevSpaces** abre workspace (opcional si DevSpaces healthy)

**Valor a narrar:** zero ticket a ops; GitOps + ApplicationSet; contrato API en portal.

---

## Task 4: Developer Hub — self-service de keys (MaaS / modelo)

**Files:** `charts/all/developer-hub/files/catalog/workshop-kuadrant-apis.yaml`, `charts/all/openshift-ai-hub/`, `values-secret.yaml.template` (`maas-credentials`)

> **Estado actual:** `plugins.kuadrant.enabled: false` en `charts/all/developer-hub/values.yaml`. Elegir **Track A** o **Track B**.

### Track A — Kuadrant habilitado (self-service keys en RHDH)

Pre-requisito: habilitar plugin Kuadrant y re-sync `developer-hub`.

- [ ] Catálogo → sistema **workshop-kuadrant-apis**
- [ ] API **MaaS LLM (ai-gateway)** → link **Request API key**
- [ ] URL: `https://developer-hub.$HUB_DOMAIN/kuadrant/api-products/ai-gateway-system/workshop-llm-tokens`
- [ ] Obtener key → probar en NeuroFace chat o curl OpenAI-compatible

### Track B — OpenShift AI + Vault (estado default workshop)

- [ ] **Step 1: Secret MaaS**

```bash
oc exec vault-0 -n vault -- vault kv get secret/hub/maas-credentials 2>/dev/null
oc get secret openshift-ai-maas-credentials -n maas-workshop 2>/dev/null
```

- [ ] **Step 2: Dashboard RHOAI**

Console link → **OpenShift AI Dashboard**  
Proyecto: `maas-workshop` → OpenShift AI Playground

- [ ] **Step 3: Correlacionar con NeuroFace chat**

```bash
oc get deploy -n neuroface -o yaml | grep -A2 'CHAT\|MAAS\|modelEndpoint' | head -20
```

Expected: endpoint MaaS configurado; chat responde en UI NeuroFace.

**Valor a narrar:** mismo portal/dominio AI para LLM; keys gobernadas (Kuadrant) o centralizadas (Vault+MaaS).

---

## Task 5: OpenShift AI — valor para imágenes / CV

**Files:** `charts/all/openshift-ai-hub/`, `charts/all/spoke-neuroface-cv/`

- [ ] **Step 1: DataScienceCluster hub**

```bash
oc get dsci,dsc -n redhat-ods-applications 2>/dev/null
oc get pods -n redhat-ods-applications | grep -E 'dashboard|kserve' | head -10
```

- [ ] **Step 2: Proyectos usuario**

```bash
oc get ns | grep -E 'ml-lab|maas-workshop'
```

Expected: `maas-workshop`, `user1-ml-lab` (si `userCount` ≥ 1).

- [ ] **Step 3: Inferencia CV en spoke (YOLO/OVMS)**

```bash
oc login --token=<east-token> --server=<east-api> --insecure-skip-tls-verify
oc get pods -n neuroface-cv
oc get inferenceservice -n neuroface-cv 2>/dev/null
curl -sk "https://neuroface-cv.${HUB_DOMAIN}/api/ppe/status" | head -c 400
```

Expected: status JSON con servicio healthy.

- [ ] **Step 4: Narrativa demo**

| Path | Rol |
|------|-----|
| RHOAI Dashboard / Workbench | Experimentación, datasets, playground |
| `neuroface-cv` + OVMS | Inferencia producción en edge |
| NeuroFace UI + webcam | Demo integrada PPE en tiempo real |

---

## Task 6: Journey Computer Vision completo (demo principal)

**Files:** `docs/content/patterns/ia-computer-vision/workshop.adoc`, `charts/all/mailpit/`

Duración: 30–45 min. Usuario: `$DEMO_USER` en **east**.

- [ ] **Acto 1** — RHDH login + scaffold (Task 3) ☐
- [ ] **Acto 2** — Abrir `https://neuroface-spoke-gateway.<east>/user/$DEMO_USER/`
- [ ] **Acto 3** — Login RHBK per-user → enrollment facial (3–5 fotos) → re-login con 2FA ☐
- [ ] **Acto 4** — Webcam PPE: casco detectado ☐
- [ ] **Acto 5** — Quitar casco → evento Kafka `cv.ppe.detections` ☐

```bash
oc logs -n mailpit deploy/ppe-kafka-mailpit -f --tail=20
```

- [ ] **Acto 6** — Mailpit: **Platform AI Computer Vision → Mailpit (PPE Alerts)**

```bash
curl -sk -o /dev/null -w '%{http_code}\n' "https://mailpit.${HUB_DOMAIN#apps.}/"
```

Expected: email de alerta visible en UI.

- [ ] **Acto 7** — (Opcional) Hub gateway 50/50

```bash
for i in $(seq 1 10); do
  curl -sk -o /dev/null -w '%{http_code} ' "https://neuroface.${HUB_DOMAIN}/api/ppe/status"
done
echo
```

---

## Task 7: Observabilidad — OpenTelemetry & Grafana

**Files:** `charts/all/observability/templates/neuroface-hub.yaml`, `platform-overview.yaml`, `opentelemetrycollector-cluster-collector.yaml`

- [ ] **Step 1: OTel collectors**

```bash
oc get opentelemetrycollector -A
oc get pods -n openshift-opentelemetry
```

- [ ] **Step 2: Grafana hub**

Console link → **Grafana Dashboards**  
URL: `https://grafana.$HUB_DOMAIN`

- [ ] **Step 3: Dashboard NeuroFace Hub**

Buscar dashboard UID **`neuroface-hub`** (tags: `neuroface`, `ai-cv`, `ppe`, `multi-cluster`).

Paneles clave durante Acto 4–6:

| Panel | Métrica | Expected under load |
|-------|---------|---------------------|
| Hub Gateway — neuroface 50/50 | `istio_requests_total{source_workload="neuroface-gateway-istio"}` | req/s > 0 |
| Backend split | east/west app + cv | tráfico en backend activo |
| East/West neuroface ns | CPU/mem pods | incremento durante demo |
| ztunnel traffic | `istio_tcp_*` namespace neuroface | bytes/s > 0 |

- [ ] **Step 4: Generar tráfico y capturar evidencia**

1. Anotar baseline (screenshot Grafana, req/s ≈ 0)
2. Ejecutar Task 6 Actos 4–7
3. Refrescar Grafana (intervalo 5m) — confirmar delta en ≤ 2 min

- [ ] **Step 5: Platform Overview**

Dashboard UID **`platform-overview`** — salud agregada plataforma.

- [ ] **Step 6: Kiali trace path (L4)**

Durante tráfico hub→spoke: Kiali → namespace `neuroface` → ver edges con mTLS.

**Gap conocido:** no hay panel dedicado Kafka→Mailpit; validar vía logs Mailpit (Task 6 Acto 5).

---

## Task 8: Console links — mapa de accesos

**Files:** `charts/all/console-links/templates/all.yaml`

Verificar menú **Platform AI Computer Vision** en hub:

| Link | Pass |
|------|------|
| Grafana Dashboards | ☐ |
| Kiali Service Mesh | ☐ |
| Skupper Console (Network) | ☐ |
| Developer Hub | ☐ |
| DevSpaces | ☐ |
| GitLab (SCM) | ☐ |
| Keycloak (SSO) | ☐ |
| Mailpit (PPE Alerts) | ☐ |
| ArgoCD (GitOps) | ☐ |
| OpenShift AI Dashboard | ☐ |
| NeuroFace API Gateway | ☐ |
| NeuroFace CV Gateway | ☐ |
| Showroom Workshop | ☐ |
| ACM Clusters | ☐ |

En spoke east:

| Link | Pass |
|------|------|
| NeuroFace Spoke Gateway | ☐ |
| Skupper Console | ☐ |
| DevSpaces | ☐ |
| OpenShift AI Dashboard | ☐ |
| Grafana (local) | ☐ |

---

## Task 9: Matriz de sign-off final

| # | Historia de valor | Evidencia | Owner | Pass |
|---|-------------------|-----------|-------|------|
| 1 | Fleet hub-spoke operativo | ACM + GitOps screenshot | Platform | ☐ |
| 2 | RHDH OIDC + SSO | Login + discovery 200 | DevEx | ☐ |
| 3 | Self-service scaffold CV | Repo GitLab + ApplicationSet | DevEx | ☐ |
| 4 | Biometric OIDC per-user | Enrollment + 2FA | Security | ☐ |
| 5 | PPE detection + Kafka→Mailpit | Email en Mailpit | Demo | ☐ |
| 6 | Multi-cluster gateway | Grafana split east/west | Mesh | ☐ |
| 7 | OpenShift AI + CV inference | RHOAI + neuroface-cv status | AI | ☐ |
| 8 | Observabilidad OTel/Grafana | Dashboard delta bajo carga | SRE | ☐ |
| 9 | Console links completos | Checklist Task 8 | Platform | ☐ |

---

## Task 10: Entregables post-revisión

- [ ] **Informe sign-off** — Task 9 completada con capturas y dominios reales
- [ ] **Lista de gaps** — bugs, docs desactualizados, plugins off (Kuadrant)
- [ ] **Guion demo** — versión 30 min (Actos 1–6) y 60 min (+ OpenShift AI + Grafana profundo)
- [ ] **(Opcional) Actualizar docs** — `workshop.adoc` con OIDC/SSO, Mailpit, console links si difieren

---

## Orden de ejecución recomendado

```
Sesión 1 (2–3 h): Task 0 → Task 1 → Task 2 → Task 8
Sesión 2 (2–3 h): Task 3 → Task 6 (journey completo)
Sesión 3 (1–2 h): Task 4 → Task 5 → Task 7 → Task 9 → Task 10
```

---

## Self-review (spec coverage)

| Requisito usuario | Task |
|-------------------|------|
| Componentes arquitectura punta a punta | 0–2, 8 |
| Journey Computer Vision | 3, 6 |
| Developer Hub self-service soluciones | 3 |
| Developer Hub keys / modelo | 4 |
| OpenShift AI imágenes | 5 |
| OTel + Grafana demo principal | 7 |
| Cambios recientes repo | Baseline + Tasks 0, 2, 6 |
