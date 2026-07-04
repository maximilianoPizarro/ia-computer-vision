# argocd-mcp

Hub-only [mcp-for-argocd](https://github.com/argoproj-labs/mcp-for-argocd) deployment exposing
hub/east/west Argo CD instances (`vp-gitops` in `vp-gitops`) to OpenShift Lightspeed or any
in-cluster MCP client.

## Architecture

1. **`argocd-local-users`** (hub + east + west): creates `ai-agent` local user with scoped RBAC
   (`get`/`sync` applications, `get` logs — no delete/prune).
2. **`argocd-mcp-spoke-export`** (east + west): copies `ai-agent-local-user` token + route URL
   into ConfigMap `argocd-mcp-hub-export` in `vp-gitops`.
3. **`argocd-mcp`** (hub): sync Jobs write tokens to Vault (`secret/hub/argocd-mcp-tokens`);
   ESO builds hub creds + `token-registry.json`; Deployment serves MCP on port 3000.

## Endpoint

```
http://argocd-mcp.argocd-mcp.svc.cluster.local:3000/mcp
```

Stateless HTTP transport (`--stateless`). Health: `GET /healthz`.

## Token lifecycle

- Argo CD auto-renews `ai-agent` tokens (`autoRenewToken: true`, `tokenLifetime: 720h`).
- PostSync Jobs + CronJobs (every 6h) refresh Vault and ESO secrets.
- Force ESO refresh:
  ```bash
  oc annotate externalsecret -n argocd-mcp --all force-sync=$(date +%s) --overwrite
  ```

## Manual verification

1. After `argocd-local-users` syncs, confirm the user sticks (ACM policy risk on spokes):
   ```bash
   oc get argocd vp-gitops -n vp-gitops -o yaml | grep -A5 localUsers
   oc get secret ai-agent-local-user -n vp-gitops
   ```
2. Populate Vault if installing via OCP console (placeholders until sync Jobs run):
   ```bash
   vault kv put secret/hub/argocd-mcp-tokens \
     hub-token=placeholder hub-url=placeholder \
     east-token=placeholder east-url=placeholder \
     west-token=placeholder west-url=placeholder
   ```
3. Wire OpenShift Lightspeed MCP client to the in-cluster Service URL above.

## ACM `mustonlyhave` risk

On east/west, ACM `ConfigurationPolicy` may revert `spec.localUsers`/`spec.rbac` on the
`vp-gitops` ArgoCD CR. See `.cursor/skills/vp-pattern-dev/SKILL.md` for mitigation options.

## Future

- TODO: Developer Hub plugin to expose MCP from the catalog UI.
