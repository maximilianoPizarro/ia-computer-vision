{{- define "spoke-neuroface.clusterName" -}}
{{- if .Values.clusterName -}}
{{- .Values.clusterName -}}
{{- else if and .Values.clusterGroup .Values.clusterGroup.name -}}
{{- .Values.clusterGroup.name -}}
{{- else -}}
{{- $g := .Values.global | default dict -}}
{{- $g.localClusterName | default "" -}}
{{- end -}}
{{- end -}}

{{- define "spoke-neuroface.maasApiKey" -}}
{{- $key := .Values.neuroface.chat.apiKey | default "" -}}
{{- if not $key -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $key = $lm.apiKey | default "" -}}
{{- end -}}
{{- $key -}}
{{- end -}}

{{- define "spoke-neuroface.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default $g.localClusterDomain | default "cluster.example.com" -}}
{{- end -}}

{{- define "spoke-neuroface.hubClusterDomainBase" -}}
{{- $d := include "spoke-neuroface.hubClusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "spoke-neuroface.gitlabApiUrl" -}}
{{- printf "https://gitlab.apps.%s/api/v4" (include "spoke-neuroface.hubClusterDomainBase" .) -}}
{{- end -}}

{{- define "spoke-neuroface.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "spoke-neuroface.clusterDomainBase" -}}
{{- $d := include "spoke-neuroface.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}
