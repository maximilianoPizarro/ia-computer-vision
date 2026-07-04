{{/*
  Resolve apps ingress domain from VP global values or explicit override.
*/}}
{{- define "models-as-a-service.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.hubClusterDomain | default $g.localClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "models-as-a-service.maasHostname" -}}
{{- printf "%s.%s" (.Values.gateway.hostnamePrefix | default "maas") (include "models-as-a-service.clusterDomain" .) -}}
{{- end -}}

{{- define "models-as-a-service.modelResourceName" -}}
{{- . | replace "." "-" -}}
{{- end -}}
