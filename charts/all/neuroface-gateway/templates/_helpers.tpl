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
  CORS lives on EnvoyFilter neuroface-gateway-cors-preflight (Lua OPTIONS
  204 + envoy_on_response), not on HTTPRoute. Keep this helper empty so
  leftover includes are safe.
*/}}
{{- define "neuroface-gateway.corsFilter" -}}
{{- end -}}

{{/*
  destub-wso2 Lua: OPTIONS 204 WITH CORS headers. An empty 204 (old helper)
  left unmatched paths without ACAO; Swagger reports that as CORS. replace()
  on the response so upstream ACAO is a single value. Do not pair ACAO *
  with Allow-Credentials.
*/}}
{{- define "neuroface-gateway.corsLua" -}}
local ALLOWED_HEADERS = "Authorization, Content-Type, X-API-Key, Accept, Origin, X-Requested-With"
local ALLOWED_METHODS = "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD"
local EXPOSE_HEADERS = "WWW-Authenticate, Content-Length, Content-Range"

function envoy_on_request(request_handle)
  local headers = request_handle:headers()
  if headers:get(":method") == "OPTIONS" then
    local origin = headers:get("origin") or "*"
    request_handle:respond({
      [":status"] = "204",
      ["access-control-allow-origin"] = origin,
      ["access-control-allow-methods"] = ALLOWED_METHODS,
      ["access-control-allow-headers"] = ALLOWED_HEADERS,
      ["access-control-max-age"] = "86400",
      ["access-control-expose-headers"] = EXPOSE_HEADERS,
    }, "")
  end
end

function envoy_on_response(request_handle)
  request_handle:headers():replace("access-control-allow-origin", "*")
  request_handle:headers():replace("access-control-expose-headers", EXPOSE_HEADERS)
  request_handle:headers():remove("access-control-allow-credentials")
end
{{- end -}}
