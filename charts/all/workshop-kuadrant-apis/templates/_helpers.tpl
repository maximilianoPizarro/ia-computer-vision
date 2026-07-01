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
