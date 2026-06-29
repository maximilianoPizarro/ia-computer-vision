# IAM and OIDC realms

Workshop APIs are protected by **Red Hat Build of Keycloak (RHBK)** realms and **Red Hat Connectivity Link (RHCL)** OIDCPolicy resources on Gateway API HTTPRoutes.

## Realms

| Realm | Purpose | Gateway route | Issuer |
|-------|---------|---------------|--------|
| `neuroface` | Main NeuroFace hub API | `neuroface-app-lb` (OIDC optional) | `https://sso.apps.<hub>/realms/neuroface` |
| `cv` | Computer vision / PPE inference | `neuroface-cv-lb` (OIDC enabled) | `https://sso.apps.<hub>/realms/cv` |
| `maas` | MaaS LLM on `ai-maas` route | `ai-maas` HTTPRoute | `https://sso.apps.<hub>/realms/maas` |

Browse **Catalog → System IAM / OIDC Realms** for OpenAPI specs and Swagger **Try it out**.

## Pre-provisioned client secrets

Each `userN` has a confidential client per realm, for example `client-cv-user1`.

Secrets are **never in Git**. They flow:

```text
Vault (secret/hub/keycloak/realms/<realm>/userN)
  → ExternalSecret (keycloak-system)
  → Kubernetes Secret keycloak-client-<realm>-userN
```

Read the secret (hub cluster):

```bash
oc get secret keycloak-client-cv-user1 -n keycloak-system \
  -o jsonpath='{.data.clientSecret}' | base64 -d
```

## Create your own client (self-service)

Workshop users have `view-clients` and `manage-clients` on the built-in `realm-management` client in each workshop realm.

1. Open `https://sso.apps.<hub>/` as `userN` / `Welcome123!`
2. Select realm `cv` (or `neuroface`, `maas`)
3. **Clients → Create client** — confidential client with redirect URI for your app
4. Copy the client secret from the **Credentials** tab

## Obtain tokens with curl

### Client credentials (machine-to-machine)

```bash
TOKEN=$(curl -sk -X POST "https://sso.apps.<hub>/realms/cv/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=client-cv-user1" \
  -d "client_secret=<secret>" \
  | jq -r .access_token)

curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://neuroface-cv.apps.<hub>/api/health"
```

### Resource owner password (demo only)

```bash
TOKEN=$(curl -sk -X POST "https://sso.apps.<hub>/realms/cv/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=client-cv-user1" \
  -d "client_secret=<secret>" \
  -d "username=user1" \
  -d "password=Welcome123!" \
  | jq -r .access_token)
```

## OIDC vs APIKEY

| Auth | Routes | Header | Use case |
|------|--------|--------|----------|
| OIDC (JWT) | `neuroface-cv-lb`, `ai-maas` | `Authorization: Bearer <jwt>` | User/service identity via Keycloak |
| APIKEY (Kuadrant) | `workshop-httpbin`, `ai-gateway` | `Authorization: APIKEY <key>` | Developer Hub API product keys |

Request API keys in Developer Hub: **Catalog → workshop-kuadrant-apis → API entity → Kuadrant tab → Request API key**.

## Workshop registration

Self-assign `userN` at `https://workshop-registration.apps.<hub>/` before starting the Showroom OIDC lab.

## Related docs

- [Kuadrant API keys](kuadrant-apis.md)
- [Vault and ESO secrets](vault-eso-secrets.md)
- Showroom module **OIDC & Keycloak Lab**
