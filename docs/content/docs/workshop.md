---
title: Workshop mode
weight: 35
---

# Workshop mode

The AI Computer Vision pattern includes an optional **workshop mode** that provisions hands-on lab users and deploys a Showroom lab guide with an embedded OpenShift CLI terminal.

Workshop mode is **enabled by default** with **30 users** (`user1` through `user30`).

## What gets provisioned

Each workshop user receives:

| Platform | Access method | Default password |
|----------|---------------|------------------|
| OCP Console | HTPasswd identity provider `workshop-users` | `Welcome123!` |
| Developer Hub | Keycloak realm `backstage` (OIDC) | `Welcome123!` |
| GitLab | User account + `ws-userN` group (owner) | `Welcome123!` |
| DevSpaces | Git credentials in `userN-devspaces` namespace | `Welcome123!` |

Special accounts:

- `platformadmin` — platform engineering group in Developer Hub
- `admin` — workshop administrator

## Showroom lab guide

The Showroom deployment on the hub cluster serves an Antora-based lab guide from the [showroom-ia-computer-vision](https://github.com/maximilianoPizarro/showroom-ia-computer-vision) repository.

Access the lab guide at:

```text
https://showroom-showroom.apps.<hub_domain>
```

The embedded terminal includes helper functions:

```bash
hub-login user1
east-login user1
west-login user1
neuroface-cv-status
neuroface-cv-traffic
neuroface-spoke-status
```

## Scaling workshop users

Change the `userCount` override in `values-hub.yaml`, `values-east.yaml`, and `values-west.yaml` for these applications:

- `platform-users`
- `developer-hub`
- `gitlab-operator`
- `openshift-ai-hub`
- `devspaces`
- `showroom` (`showroom.terminal.userCount`)

Example for 50 users on the hub:

```yaml
platform-users:
  overrides:
    - name: userCount
      value: "50"
```

Apply the same value across all user-provisioning charts to keep accounts consistent.

## Disabling workshop mode

To disable Showroom while keeping user provisioning, set `showroom.enabled: "false"` in the showroom application overrides.

To reduce or remove workshop users, set `userCount` to `"0"` on `platform-users` and remove or disable dependent workshop applications.

## Charts involved

| Chart | Cluster | Sync wave | Purpose |
|-------|---------|-----------|---------|
| `platform-users` | Hub, east, west | 0 | HTPasswd users, OAuth IDP, RBAC |
| `developer-hub` | Hub | 4 | Keycloak realm + catalog users |
| `gitlab-operator` | Hub | 3 | GitLab user bootstrap |
| `devspaces` | Hub, east, west | 7 | Per-user git credentials |
| `showroom` | Hub | 5 | Lab guide + terminal |
