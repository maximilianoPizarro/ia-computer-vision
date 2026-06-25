{{- define "kafka-console.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}
