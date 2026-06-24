# Login guide

## Developer Hub (recommended entry)

1. Open `https://developer-hub.<hub-apps-domain>`
2. Sign in with **OIDC** (Keycloak).
3. Username: `userN` (e.g. `user1`) — same as GitLab.
4. Password: `Welcome123!` (demo default).

## OpenShift console (hub, east, west)

Developer Hub uses **Keycloak (OIDC)**. The **OpenShift console** uses **htpasswd** — not the same login screen.

1. Open the cluster console URL (hub, east, or west).
2. On the login page, click **workshop-users** (not `rhbk`, not the default OpenShift login).
3. Username: `user1` (or `user2`…`user50`, `platformadmin`).
4. Password: `Welcome123!` (demo default).

If login fails after choosing the wrong provider, sign out completely and try again with **workshop-users**.

### Console still fails (500 or “authentication error”)

1. Confirm you chose **workshop-users** (not `rhbk`).
2. Password is exactly `Welcome123!` (capital W, ends with `!`).
3. Ask a **cluster-admin** to repair the secret (the setup Job needs `httpd` for bcrypt; `ose-cli` alone cannot generate hashes):
   ```bash
   oc apply -f scripts/fix-htpasswd-users-secret-job.yaml
   oc wait --for=condition=complete job/htpasswd-users-secret-fix -n openshift-gitops --timeout=3m
   oc logs job/htpasswd-users-secret-fix -n openshift-gitops --all-containers
   ```
   Run on **hub, east, and west**. The first line of the secret must start with `$2y$` (bcrypt), not `$6$`.
4. If one user still fails after a secret refresh, stale identities can block login — admin runs:
   `oc get identities | grep workshop-users` then `oc delete identity '<name>'` for that user, and retry.

Workshop users have **cluster-reader** on all clusters (view namespaces, workloads, routes; not cluster-admin).

## GitLab

- URL: `https://gitlab.apps.<hub-apps-domain>`
- User: `user1` (your workshop id)
- Password: `Welcome123!`
- Your org: `ws-user1` (repos created by the scaffolder land here)

## DevSpaces (east or west)

DevSpaces runs **on the spoke** you selected in the template — not on the hub.

- East: `https://devspaces.<east-apps-domain>`
- West: `https://devspaces.<west-apps-domain>`
- Login: same `userN` / `Welcome123!` via cluster htpasswd on that spoke.

Use the **Open in DevSpaces** link on your catalog component so the correct spoke and GitLab repo are pre-filled.
