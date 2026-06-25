{{- define "skupper-network-observer.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "cluster.example.com" -}}
{{- end -}}

{{- define "skupper-network-observer.domainBase" -}}
{{- $d := include "skupper-network-observer.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}
