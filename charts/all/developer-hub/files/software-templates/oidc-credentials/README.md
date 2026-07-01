# OIDC credentials self-service template

Developer Hub Software Template that provisions OIDC clients in **Keycloak realm `cv`**
using only existing plugins (no custom dynamic plugin or sidecar service).

## Plugins used

| Plugin | Action / purpose |
|--------|------------------|
| `roadiehq-scaffolder-backend-module-http-request` | `http:backstage:request` → Keycloak Admin REST proxy |

No custom scaffolder actions are registered in the backend.

**Why there's no email step:** `POST /api/notifications` (Backstage's notifications-backend "create
notification" route) only allows `service` credentials (`allow: ["service"]` in
`@backstage/plugin-notifications-backend`'s router — verified in
`dynamic-plugins-root/backstage-plugin-notifications-backend-dynamic-*/node_modules/@backstage/plugin-notifications-backend/dist/service/router.cjs.js`).
The generic `http:backstage:request` action can only carry `user`-derived credentials
(the initiator's, exchanged for a plugin token, or the raw `backstageToken` — both are
`user` principals), so calling that endpoint from a template step always fails with
`403 {"error":{"name":"NotAllowedError","message":"This endpoint does not allow 'user' credentials"}}`.
This is a Backstage platform restriction, not a bug in this template or the proxy config.
The secret is instead shown once on the scaffolder task's own result page
(`spec.output.text`). To send it by email for real, add
`@backstage/plugin-scaffolder-backend-module-notifications` (the `notification:send`
action, which runs in-process with genuine service credentials) as a dynamic plugin —
it is not bundled in RHDH's default image or its `rhdh-plugin-export-overlays` OCI
registry, so it would need to be fetched from the public npm registry.

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

Template steps call (paths as seen by the `http:backstage:request` action, which
prepends `/api/` itself -- do **not** include `/api/` in the template's `path:`, that
produces a `.../api/api/proxy/...` 404):

- `/proxy/keycloak/realms/cv/protocol/openid-connect/token`
- `/proxy/keycloak/admin/realms/cv/clients`

`/keycloak` must also set `allowedHeaders: ['Authorization']` -- Backstage's proxy only
forwards CORS-safe headers by default and silently drops a caller-supplied
`Authorization` header otherwise, which surfaces as a genuine (Keycloak-side, not
Backstage's) 401 on every admin-API step even with a valid token.

## API dropdown (EntityPicker)

APIs annotated with `workshop/oidc-self-service-target: "true"` in [`iam-realms.yaml`](../../catalog/iam-realms.yaml):

| API | OIDCPolicy | Actual issuer |
|-----|------------|---------------|
| `neuroface-openapi` | `oidc-neuroface` | realm `neuroface` |
| `neuroface-cv-openapi` | `oidc-cv` | realm **`cv`** |
| `maas-openapi` | `oidc-maas` | realm `maas` |

**PoC:** the template always creates clients in realm **`cv`**. The token works immediately for **`neuroface-cv-openapi`**. For other APIs the dropdown provides traceability (`clientId`, `targetApi` attribute); in production map API → actual realm issuer.

## Credential delivery (no email)

The template's last step (`get-secret`) reads the client secret back from Keycloak and
the scaffolder shows it once, on the task result page ("OIDC credentials (shown once --
copy them now)"). Copy it immediately -- re-running the template rotates the secret
(Keycloak issues a new one for the same client on each `get-secret` call against an
existing client, and re-running `create-client-*` against an already-existing `clientId`
will fail; delete the old client first if you need a fresh one).

`backstage-plugin-notifications-backend-module-email-dynamic` (relaying through Mailpit)
is still installed and used for other in-app notifications, but **not** for this
template -- see "Why there's no email step" above for why the notifications REST API
can't be called from a scaffolder step at all, regardless of transport.

## Vault — provisioner secret

```bash
oc exec vault-0 -n vault -- vault kv put secret/hub/keycloak/realms/cv/backstage-provisioner \
  clientSecret="$(openssl rand -base64 24)"
```

The same value must exist in Keycloak (realm import placeholder) and in `keycloak-provisioner-credentials` (Developer Hub).

## PoC limitations

| Aspect | Status |
|--------|--------|
| Visible template output | `clientId` **and** `clientSecret`, shown once in plain text |
| Scaffolder task history | Secret is retained in the task run history (`get-secret` step output) |
| Delivery channel | In-app only (no email -- see above) |
| Catalog Resource | Not registered (PoC) |

**PoC ONLY:** showing the secret in plain text on the result page (and keeping it in task
history) is acceptable only for this PoC. In production use expiring / reveal-once
delivery (e.g. Vault response-wrapping) instead of either email or an on-screen result.

## Verification

1. Sync ArgoCD `developer-hub` and `rhbk-iam`.
2. Confirm Secret `keycloak-backstage-provisioner` in `keycloak-system`.
3. Developer Hub → **Create** → **OIDC credentials self-service (Keycloak cv)**.
4. Choose API `neuroface-cv-openapi`, grant `client_credentials`, user `user1`.
5. Output: `clientId` and `clientSecret` shown directly on the task result page.
6. Test token (curl example is also printed on the result page):

```bash
curl -sk -X POST 'https://sso.<apps-domain>/realms/cv/protocol/openid-connect/token' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=client-neuroface-cv-openapi-<label>' \
  -d 'client_secret=<from-the-result-page>'
```

## catalog-info.example.yaml

Documentation-only example of an `oidc-credential` Resource (no secret) for a future `catalog:register` — not used in this PoC.
