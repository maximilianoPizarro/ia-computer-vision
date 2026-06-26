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
