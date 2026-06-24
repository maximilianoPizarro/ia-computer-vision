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
