# models-as-a-service

Hub-only chart that enables native **Red Hat OpenShift AI 3.4 Models-as-a-Service**
(Connectivity Link + Gateway API) for the external RHDP endpoint
`maas-rhdp.apps.maas.redhatworkshops.io`.

## What it deploys

- `Gateway` `maas-default-gateway` in `openshift-ingress` (class `data-science-gateway-class`)
- Authorino TLS: PostSync Jobs discover the live Authorino Service/Deployment
  (`kuadrant-system` or `redhat-connectivity-link-operator`) and annotate /
  set `SSL_CERT_FILE` — never create a ports-less Service via SSA
- Dedicated PostgreSQL for MaaS API keys (`models-as-a-service` namespace)
- `ExternalSecret` → `maas-db-config` in `redhat-ods-applications`
- `OdhDashboardConfig` patch (MaaS / Gen AI Studio / Auth Policies)
- OpenShift `Group` `maas-workshop-users` (`user1`..`userN`)
- MaaS CRs: `Tenant`, `ExternalModel`, `MaaSModelRef`, `MaaSSubscription`, `MaaSAuthPolicy`

## Prerequisites (other charts)

- `workshop-kuadrant-apis`: `Kuadrant` singleton with `observability.enable: true`
- `openshift-ai-hub`: `maas.native.enabled=true` → `kserve.modelsAsService: Managed`
- `workshop-kuadrant-apis`: `maas.authorinoTls=true` when native MaaS is enabled

The legacy Kuadrant `AuthPolicy`/`RateLimitPolicy` path (`apis.maas.enabled`) stays
enabled in parallel until you validate native MaaS, then set
`workshop-kuadrant-apis.apis.maas.enabled=false`.

## Gen AI Studio: Playground, MaaS, and MCP servers

This chart's `OdhDashboardConfig` patch sets `genAiStudio`, `modelAsService`, and
`maasAuthPolicies` so the dashboard shows **Gen AI studio** with **Playground**,
**AI asset endpoints** (native MaaS models), and **API keys**.

**Llama Stack Operator** must also be `Managed` in `DataScienceCluster` — without
it the dashboard only shows API keys under Gen AI studio. Chart
`openshift-ai-hub` enables this when `genAiStudio.llamaStackOperator=true`
(default) or `playground.enabled=true`.

**MCP (Model Context Protocol) tool servers** for the Playground MCP tab are
registered by `charts/all/openshift-ai-hub` (`mcp.servers` → ConfigMap
`gen-ai-aa-mcp-servers` in `redhat-ods-applications`). By default this registers
`argocd-mcp` so Playground chats can query/sync Argo CD Applications as a tool.

Workshop users (`user1`..`userN` in group `maas-workshop-users`) see MaaS models
and can create API keys. Log in as a workshop user — not `kubeadmin` — to verify
the full Gen AI studio nav.

## Manual steps after first sync

1. Ensure Vault path `secret/hub/models-as-a-service-db` exists (`make load-secrets` on CLI installs).
2. First sync may fail on MaaS CRDs — wait for DSC to reconcile `modelsAsService`, then re-sync.
3. Verify tenant readiness:
   ```bash
   oc get tenants.maas.opendatahub.io default-tenant -n models-as-a-service \
     -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
   ```
4. Confirm workshop users can create API keys in Gen AI Studio and call the MaaS gateway.
5. Disable legacy path: `workshop-kuadrant-apis.apis.maas.enabled=false` in `values-hub.yaml`.

## Optional cleanup

Remove orphaned Kuadrant CR (pre-existing bug, not managed by Git):

```bash
oc delete kuadrant kuadrant -n redhat-connectivity-link-operator
```
