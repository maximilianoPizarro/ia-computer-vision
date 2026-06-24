# Hybrid Mesh Platform — Workshop Onboarding

Welcome to the **hub-spoke Industrial Edge** demo on OpenShift 4.20.

## What you get

| Capability | Where |
|------------|--------|
| Developer Hub (scaffolder, catalog, topology) | `https://developer-hub.<hub-apps-domain>` |
| GitLab org per user | `ws-<username>` on hub GitLab |
| DevSpaces (east or west) | Chosen when you run a template |
| Internal Quay registry | Org `workshop` — images from Tekton |
| ACM, Kiali, Skupper | OpenShift console (hub) + entity links |

## Architecture

```text
Hub (ACM, GitOps, GitLab, Quay, Developer Hub)
  ├── East spoke — Industrial Edge, DevSpaces, mesh
  └── West spoke — Industrial Edge, DevSpaces, mesh
```

## Quick start

1. Read [Login](login.md) — credentials and URLs.
2. Open **Developer Hub** → **Create** → **Industrial Edge** template.
3. Pick **east** or **west**; your repo lands in GitLab and deploys via Argo CD.
4. Use **Open in DevSpaces** on the catalog entity (spoke DevSpaces URL).
5. See [Pipelines and Quay](pipelines.md) for builds; [Observability](observability.md) for ACM/Kiali/Skupper.

## Workshop users

- Users: `user1` … `user50` (up to `user200` if enabled by admins)
- Password (demo): `Welcome123!`
- Same password for: OpenShift console (htpasswd), Developer Hub (Keycloak), GitLab, DevSpaces on the spoke where you work
