# OIDC credentials self-service template

Developer Hub Software Template that provisions OIDC clients in **Keycloak realm `cv`**
using only existing plugins (no custom dynamic plugin or sidecar service).

## Plugins used

| Plugin | Action / purpose |
|--------|------------------|
| `roadiehq-scaffolder-backend-module-http-request` | `http:backstage:request` → Keycloak Admin REST proxy + `/api/notifications` |
| `backstage-plugin-notifications-backend-module-email` | SMTP processor → Mailpit (PoC) |

No custom scaffolder actions are registered in the backend.

## Keycloak prerequisites

1. Client **`backstage-provisioner`** in realm **`cv`** (Helm: [`rhbk-iam/templates/realm-import.yaml`](../../../rhbk-iam/templates/realm-import.yaml)).
2. Secret synced from Vault via ExternalSecret `keycloak-backstage-provisioner` (namespace `keycloak-system`).
3. Developer Hub credentials: Secret `keycloak-provisioner-credentials` → backend pod env vars.

### Production — Fine-Grained Admin Permissions (FGAP)

In real environments, restrict the `backstage-provisioner` service account with **FGAP**
(scope `create` on Clients), not global `manage-clients` on the realm.

### Future migration — Dynamic Client Registration (DCR)

Alternative to Admin REST: [Keycloak DCR with Initial Access Token](https://www.keycloak.org/docs/latest/securing_apps/#_client_registration).

## Keycloak proxy (`app-config`)

Entry in `proxy.endpoints['/keycloak']` pointing to `https://sso.<apps-domain>`.

Template steps call:

- `/api/proxy/keycloak/realms/cv/protocol/openid-connect/token`
- `/api/proxy/keycloak/admin/realms/cv/clients`

## API dropdown (EntityPicker)

APIs annotated with `workshop/oidc-self-service-target: "true"` in [`iam-realms.yaml`](../../catalog/iam-realms.yaml):

| API | OIDCPolicy | Actual issuer |
|-----|------------|---------------|
| `neuroface-openapi` | `oidc-neuroface` | realm `neuroface` |
| `neuroface-cv-openapi` | `oidc-cv` | realm **`cv`** |
| `maas-openapi` | `oidc-maas` | realm `maas` |

**PoC:** the template always creates clients in realm **`cv`**. The token works immediately for **`neuroface-cv-openapi`**. For other APIs the dropdown provides traceability (`clientId`, `targetApi` attribute); in production map API → actual realm issuer.

## Mailpit (PoC)

- SMTP: `mailpit.mailpit.svc.cluster.local:1025` (no TLS/auth)
- UI: `https://mailpit.<apps-domain>/` (port 8025 via route)

After running the template, check Mailpit for the email with `client_id` and `client_secret`.

## How to replace the email transport

Delivery is not coupled to custom code: it uses the **`backstage-plugin-notifications-backend-module-email-dynamic`** plugin.

Edit `pluginConfig` in [`configmap-dynamic-plugins-rhdh.yaml`](../../../templates/configmap-dynamic-plugins-rhdh.yaml):

```yaml
notifications:
  processors:
    email:
      transportConfig:
        transport: smtp          # or ses, sendmail, azure
        hostname: mailpit.mailpit.svc.cluster.local
        port: 1025
        # username / password for corporate SMTP
      sender: notifications@developer-hub.local
      filter:
        minSeverity: high
```

For **SES**, set `transport: ses` and add `sesConfig` per the Backstage notifications email plugin documentation.

## Vault — provisioner secret

```bash
oc exec vault-0 -n vault -- vault kv put secret/hub/keycloak/realms/cv/backstage-provisioner \
  clientSecret="$(openssl rand -base64 24)"
```

The same value must exist in Keycloak (realm import placeholder) and in `keycloak-provisioner-credentials` (Developer Hub).

## PoC limitations

| Aspect | Status |
|--------|--------|
| Visible template output | No `clientSecret` |
| Scaffolder task history | **Partial** — `get-secret` step stores the secret in the task run |
| Email | Secret in `payload.description` (notifications DB + Mailpit) |
| Catalog Resource | Not registered (PoC) |
| HTML email | Plain text via notifications |

**PoC ONLY:** sending the secret in plain text by email is acceptable only with Mailpit. In production use expiring / reveal-once delivery (e.g. Vault response-wrapping).

## Verification

1. Sync ArgoCD `developer-hub` and `rhbk-iam`.
2. Confirm Secret `keycloak-backstage-provisioner` in `keycloak-system`.
3. Developer Hub → **Create** → **OIDC credentials self-service (Keycloak cv)**.
4. Choose API `neuroface-cv-openapi`, grant `client_credentials`, user `user1`.
5. Output: clientId without secret; email in Mailpit.
6. Test token:

```bash
curl -sk -X POST 'https://sso.<apps-domain>/realms/cv/protocol/openid-connect/token' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=client-neuroface-cv-openapi-<label>' \
  -d 'client_secret=<from-mailpit>'
```

## catalog-info.example.yaml

Documentation-only example of an `oidc-credential` Resource (no secret) for a future `catalog:register` — not used in this PoC.
