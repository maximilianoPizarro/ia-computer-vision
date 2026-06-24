{{- define "spoke-neuroface-cv.minioEndpoint" -}}
{{- $ms := .Values.yoloPpeServing.modelStorage | default dict -}}
{{- $ms.endpoint | default "http://minio-hub.service-interconnect.svc:9000" -}}
{{- end -}}

{{- define "spoke-neuroface-cv.clusterName" -}}
{{- if .Values.clusterName -}}
{{- .Values.clusterName -}}
{{- else if and .Values.clusterGroup .Values.clusterGroup.name -}}
{{- .Values.clusterGroup.name -}}
{{- else -}}
{{- $g := .Values.global | default dict -}}
{{- $g.localClusterName | default "" -}}
{{- end -}}
{{- end -}}
