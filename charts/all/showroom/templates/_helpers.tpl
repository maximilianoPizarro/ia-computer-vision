{{/*
  Resolve apps ingress domain from VP global values or explicit override.
*/}}
{{- define "showroom.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "showroom.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "showroom.clusterDomain" .) -}}
{{- end -}}

{{- define "showroom.clusterDomainBase" -}}
{{- $d := include "showroom.hubClusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "showroom.hubApiUrl" -}}
{{- printf "https://api.%s:6443" (include "showroom.clusterDomainBase" .) -}}
{{- end -}}

{{- define "showroom.eastDomain" -}}
{{- .Values.clusters.east.domain | default "" -}}
{{- end -}}

{{- define "showroom.westDomain" -}}
{{- .Values.clusters.west.domain | default "" -}}
{{- end -}}

{{- define "showroom.eastApiUrl" -}}
{{- .Values.clusters.east.apiUrl | default "" -}}
{{- end -}}

{{- define "showroom.westApiUrl" -}}
{{- .Values.clusters.west.apiUrl | default "" -}}
{{- end -}}
