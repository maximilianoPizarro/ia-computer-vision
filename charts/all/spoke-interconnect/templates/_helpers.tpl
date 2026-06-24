{{- define "spoke-interconnect.clusterName" -}}
{{- if .Values.clusterName -}}
{{- .Values.clusterName -}}
{{- else if and .Values.clusterGroup .Values.clusterGroup.name -}}
{{- .Values.clusterGroup.name -}}
{{- else -}}
{{- $g := .Values.global | default dict -}}
{{- $g.localClusterName | default "" -}}
{{- end -}}
{{- end -}}
