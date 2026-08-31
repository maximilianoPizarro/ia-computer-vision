{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "neuroface-gateway.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "neuroface-gateway.hubOrigin" -}}
{{- printf "https://developer-hub.%s" (include "neuroface-gateway.clusterDomain" .) -}}
{{- end -}}

{{- define "neuroface-gateway.consoleOrigin" -}}
{{- printf "https://console-openshift-console.%s" (include "neuroface-gateway.clusterDomain" .) -}}
{{- end -}}

{{/*
  CORS lives on EnvoyFilter neuroface-gateway-cors-preflight (native
  envoy.filters.http.cors + Lua OPTIONS 204), not on HTTPRoute. A static
  ResponseHeaderModifier can only emit one Access-Control-Allow-Origin, so
  OpenShift console Swagger (console-openshift-console.<domain>) fails while
  Developer Hub works. Keep this helper empty so leftover includes are safe.
*/}}
{{- define "neuroface-gateway.corsFilter" -}}
{{- end -}}

{{/*
  Lua OPTIONS short-circuit for Hub + OpenShift console origins only.
  Do not set Access-Control-Allow-* here -- the envoy.filters.http.cors
  policy reflects Origin. Setting both duplicates the header and browsers
  reject it.
*/}}
{{- define "neuroface-gateway.corsLua" -}}
local allowed = {
  [{{ include "neuroface-gateway.hubOrigin" . | quote }}] = true,
  [{{ include "neuroface-gateway.consoleOrigin" . | quote }}] = true,
}
function envoy_on_request(request_handle)
  local headers = request_handle:headers()
  local origin = headers:get("origin") or ""
  if headers:get(":method") == "OPTIONS" and allowed[origin] then
    request_handle:respond({[":status"] = "204"}, "")
  end
end
{{- end -}}
