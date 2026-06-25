{{- define "mailpit.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "mailpit.clusterDomainBase" -}}
{{- $d := include "mailpit.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "mailpit.neurofaceUrl" -}}
{{- if .Values.ppeKafkaMailpit.neurofaceUrl -}}
{{- .Values.ppeKafkaMailpit.neurofaceUrl -}}
{{- else -}}
{{- printf "https://neuroface-gateway.%s" (include "mailpit.clusterDomainBase" .) -}}
{{- end -}}
{{- end -}}
