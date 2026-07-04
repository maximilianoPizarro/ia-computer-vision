# models-as-a-service

Hub-only chart that enables native **Red Hat OpenShift AI 3.4 Models-as-a-Service**
(Connectivity Link + Gateway API) for the external RHDP endpoint
`maas-rhdp.apps.maas.redhatworkshops.io`.

## What it deploys

- `Gateway` `maas-default-gateway` in `openshift-ingress` (class `data-science-gateway-class`)
- Authorino TLS serving cert annotation + PostSync/CronJob for `SSL_CERT_FILE` env vars
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
