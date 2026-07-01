{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "neuroface-gateway.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{/*
  CORS response headers so the RHDH-embedded Swagger UI (served from
  developer-hub.<domain>, a different origin than these gateway routes) can
  call them via "Try it out", including preflighted requests (custom headers
  like Authorization). Uses "set" (not "add") because some backends already
  emit their own Access-Control-Allow-* on OPTIONS -- "add" would duplicate
  the header, which browsers reject as invalid.
*/}}
{{- define "neuroface-gateway.corsFilter" -}}
- type: ResponseHeaderModifier
  responseHeaderModifier:
    set:
      - name: Access-Control-Allow-Origin
        value: {{ printf "https://developer-hub.%s" (include "neuroface-gateway.clusterDomain" .) | quote }}
      - name: Access-Control-Allow-Methods
        value: "GET, POST, PUT, PATCH, DELETE, OPTIONS"
      - name: Access-Control-Allow-Headers
        value: "Authorization, Content-Type, Accept"
      - name: Access-Control-Allow-Credentials
        value: "true"
      - name: Access-Control-Max-Age
        value: "600"
{{- end -}}
