# openshift-lightspeed

Hub-only chart that installs the **OpenShift Lightspeed** operator (console AI
assistant) and preconfigures it with:

- **LLM provider**: the workshop AI Gateway (`charts/all/workshop-kuadrant-apis`),
  using the auto-generated `platform-ai-gateway-key` (Vault path
  `secret/hub/ai-gateway-platform-keys`), sent as a standard OpenAI-compatible
  `Authorization: Bearer <apitoken>` header.
- **MCP server**: `charts/all/argocd-mcp`'s in-cluster endpoint
  (`http://argocd-mcp.argocd-mcp.svc.cluster.local:3000/mcp`), so the console
  assistant can query/sync GitOps applications across hub, east, and west.

## Why Bearer, not APIKEY

The workshop AI Gateway's `ai-maas` route normally expects a Kuadrant `APIKEY`
prefix (see `workshop-kuadrant-apis/templates/policies.yaml`). OpenShift
Lightspeed's `type: openai` LLM provider always sends a standard
`Authorization: Bearer <apitoken>` header and does not support a custom auth
scheme. `workshop-kuadrant-apis`'s `ai-maas-auth` AuthPolicy was extended with
a second, purely additive identity source (`api-key-users-bearer`) that
accepts the *same* API keys with a `Bearer` prefix — Authorino ORs every
identity source, so existing `APIKEY`-prefixed clients (Developer Hub,
module 05 curl examples) are unaffected.

## Prerequisites

- `charts/all/workshop-kuadrant-apis` (`apis.maas.enabled=true`) for the AI Gateway
- `charts/all/argocd-mcp` for the MCP endpoint
- Vault path `secret/hub/ai-gateway-platform-keys` populated (auto-generated)

## Manual verification

```bash
oc get olsconfig cluster -o jsonpath='{.status}'
oc get pods -n openshift-lightspeed
oc rsh -n openshift-lightspeed deploy/lightspeed-app-server -- \
  curl -s http://localhost:8080/v1/mcp-servers   # via console proxy in practice
```

In the OpenShift web console, open the Lightspeed chat (bottom-right "?" menu
or the dedicated icon) and ask something like *"Which Argo CD applications on
the hub are OutOfSync?"* — the assistant should call the `argocd-mcp` tools.

When the LLM backend is a local vLLM model (hub-only GPU overlay), set
`llm.contextWindowSize` to match the ServingRuntime `--max-model-len` (default
8192 in `values-hub-only.yaml`). Lightspeed defaults to 128k tokens; MCP tool
calls exceed smaller models and surface `[LLM Backend] The request exceeds the
model's token limit`.

## Known limitation

The Gen AI Studio native MaaS path (`models-as-a-service` chart) has an
unrelated, RHOAI-operator-level Envoy/WASM bug on this cluster (Authorino
gRPC dispatch failure on `maas-default-gateway`) — this chart deliberately
uses the legacy Kuadrant AI Gateway instead, which does not hit that bug.
