{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "workshop-kuadrant-apis.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "workshop-kuadrant-apis.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "workshop-kuadrant-apis.clusterDomain" .) -}}
{{- end -}}

{{/*
  Any Developer Hub API key minted for workshop-kuadrant-apis works on all workshop-apis routes.
*/}}
{{- define "workshop-kuadrant-apis.workshopApiKeySelector" -}}
matchLabels:
  kuadrant.io/apikey: "true"
  devportal.kuadrant.io/apikey-namespace: {{ .Values.workshopGateway.namespace | quote }}
{{- end -}}

{{/*
  Shared by authorino-apikey-secret-resync.yaml's one-shot PostSync Job and
  its CronJob -- restart Authorino only if a kuadrant.io/apikey=true Secret
  exists that's newer than Authorino's own pod start time (see that file's
  header comment for why this is needed at all).
*/}}
{{- define "workshop-kuadrant-apis.authorinoResyncScript" -}}
set -euo pipefail

# Idempotent: only patches if "watch" is missing, never appends a duplicate,
# and locates the "secrets" rule by content (not a hardcoded array index --
# authorino-operator could reorder its own generated rules on a CSV upgrade).
# authorino-manager-role is OLM/authorino-operator-owned (olm.managed=true),
# not reconciled continuously like an ArgoCD-owned resource -- a one-time
# patch persists until the operator's next CSV upgrade re-applies its RBAC.
if oc get clusterrole authorino-manager-role -o json >/dev/null 2>&1; then
  oc get clusterrole authorino-manager-role -o json | python3 -c '
import json, sys
cr = json.load(sys.stdin)
changed = False
for i, rule in enumerate(cr.get("rules", [])):
    if rule.get("apiGroups") == [""] and "secrets" in rule.get("resources", []):
        if "watch" not in rule.get("verbs", []):
            print(f"PATCH:{i}")
            changed = True
        break
' > /tmp/authorino-rbac-check.txt || true
  PATCH_IDX=$(grep -o 'PATCH:[0-9]*' /tmp/authorino-rbac-check.txt 2>/dev/null | cut -d: -f2 || true)
  if [ -n "$PATCH_IDX" ]; then
    echo "Adding missing 'watch' verb to authorino-manager-role (secrets rule, index $PATCH_IDX)"
    oc patch clusterrole authorino-manager-role --type json \
      -p "[{\"op\":\"add\",\"path\":\"/rules/$PATCH_IDX/verbs/-\",\"value\":\"watch\"}]" || true
  fi
fi

NS="{{ .Values.authorinoApikeySecretResync.namespace | default "kuadrant-system" }}"
DEP="{{ .Values.authorinoApikeySecretResync.deployment | default "authorino" }}"
SELECTOR="{{ .Values.authorinoApikeySecretResync.podSelector | default "authorino-resource=authorino" }}"

POD_START=$(oc get pods -n "$NS" -l "$SELECTOR" --field-selector=status.phase=Running -o jsonpath='{.items[0].status.startTime}' 2>/dev/null || true)
if [ -z "$POD_START" ]; then
  echo "WARN: could not determine $DEP pod start time in $NS; skipping"
  exit 0
fi
POD_START_EPOCH=$(date -d "$POD_START" +%s)

NEWEST_SECRET=$(oc get secrets -A -l kuadrant.io/apikey=true \
  -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null \
  | sort -r | head -1 || true)
if [ -z "$NEWEST_SECRET" ]; then
  echo "No kuadrant.io/apikey=true secrets found; nothing to sync"
  exit 0
fi
NEWEST_SECRET_EPOCH=$(date -d "$NEWEST_SECRET" +%s)

if [ "$NEWEST_SECRET_EPOCH" -gt "$POD_START_EPOCH" ]; then
  echo "Newest API key secret ($NEWEST_SECRET) postdates $DEP's startup ($POD_START) -- restarting to re-index"
  oc rollout restart "deployment/$DEP" -n "$NS"
  oc rollout status "deployment/$DEP" -n "$NS" --timeout=120s
else
  echo "$DEP already indexes the newest API key secret ($NEWEST_SECRET <= $POD_START); nothing to do"
fi
{{- end -}}

{{- define "workshop-kuadrant-apis.maasApiKey" -}}
{{- $key := .Values.apis.maas.apiKey | default "" -}}
{{- if not $key -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $key = $lm.apiKey | default "" -}}
{{- end -}}
{{- $key -}}
{{- end -}}

{{/*
  CORS response headers so the RHDH-embedded Swagger UI (served from
  developer-hub.<domain>, a different origin than these gateway routes) can
  call them via "Try it out", including preflighted requests (custom headers
  like Authorization: APIKEY <key> or Bearer). Uses "set" (not "add") since
  some upstreams (e.g. httpbin.org) already emit their own
  Access-Control-Allow-* -- "add" would duplicate the header, which browsers
  reject as invalid.
*/}}
{{- define "workshop-kuadrant-apis.corsFilter" -}}
- type: ResponseHeaderModifier
  responseHeaderModifier:
    set:
      - name: Access-Control-Allow-Origin
        value: {{ printf "https://developer-hub.%s" (include "workshop-kuadrant-apis.hubClusterDomain" .) | quote }}
      - name: Access-Control-Allow-Methods
        value: "GET, POST, PUT, PATCH, DELETE, OPTIONS"
      - name: Access-Control-Allow-Headers
        value: "Authorization, Content-Type, Accept"
      - name: Access-Control-Allow-Credentials
        value: "true"
      - name: Access-Control-Max-Age
        value: "600"
{{- end -}}
