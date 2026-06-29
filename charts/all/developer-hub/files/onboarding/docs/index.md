# Workshop onboarding — AI Computer Vision

Welcome to the **AI Computer Vision at the Edge** workshop on OpenShift 4.20+.

## What you get

| Capability | Where |
|------------|--------|
| Developer Hub (scaffolder, catalog, plugins) | `https://developer-hub.apps.<hub-domain>` |
| AI CV software template | **Create** → **AI Computer Vision at the Edge** |
| GitLab repos | Group `ws-workshop` — `neuroface-<username>` |
| DevSpaces | Hub or spoke URL from catalog entity link |
| NeuroFace + RHBK (per user) | Spoke gateway `/user/<you>/` |
| ACM, Kiali, Skupper | Developer Hub entity tabs + OpenShift console |

## Architecture

```text
Hub (ACM, GitOps, Vault, ESO, GitLab, Developer Hub, OpenShift AI)
  ├── East spoke — NeuroFace gateway, PPE/YOLO, mesh, user namespaces
  └── West spoke — NeuroFace gateway, PPE/YOLO, mesh, user namespaces
```

Platform secrets flow: **Vault → ESO → OpenShift Secret → Pods** (never stored in Git).

## Quick start

1. Read [Login](login.md) — credentials and URLs.
2. Read [AI Computer Vision scaffolding](ai-computer-vision-scaffolding.md) — template journey and expected results.
3. Open **Developer Hub** → **Create** → **AI Computer Vision at the Edge**.
4. Pick **east** or **west**; your repo deploys via Argo CD ApplicationSet.
5. Open catalog entity links: NeuroFace gateway, RHBK admin, DevSpaces, Tekton.
6. Optional: [Vault and ESO](vault-eso-secrets.md) for operators; [Kuadrant MaaS keys](kuadrant-apis.md) for chat.
7. [IAM and OIDC realms](iam-oidc-realms.md) — Keycloak realms, JWT curl, self-service clients.

## Workshop users

- Users: `user1` … `user30` (extend via `userCount` in values)
- Password (demo): `Welcome123!`
- Same password for: OpenShift (htpasswd), Developer Hub (Keycloak), GitLab, RHBK user in your instance

## Legacy Industrial Edge template

The **Industrial Edge** templates remain available for multi-cluster IoT demos. See [Create a component (Industrial Edge)](create-component.md).
