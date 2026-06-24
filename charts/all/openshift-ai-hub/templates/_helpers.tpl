{{/*
  MaaS API key: explicit maas.apiKey or RHDP litemaas.apiKey (never commit to Git).
*/}}
{{- define "openshift-ai-hub.maasApiKey" -}}
{{- $key := .Values.maas.apiKey | default "" -}}
{{- if not $key -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $key = $lm.apiKey | default "" -}}
{{- end -}}
{{- $key -}}
{{- end -}}

{{- define "openshift-ai-hub.maasApiUrl" -}}
{{- $base := .Values.maas.endpoint | default "" -}}
{{- if not $base -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $base = $lm.apiUrl | default "" -}}
{{- end -}}
{{- if not $base -}}
{{- $base = "https://maas-rhdp.apps.maas.redhatworkshops.io" -}}
{{- end -}}
{{- trimSuffix "/" $base -}}
{{- end -}}

{{- define "openshift-ai-hub.maasModel" -}}
{{- $model := "" -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $model = $lm.model | default "" -}}
{{- if not $model -}}
{{- $model = "llama-scout-17b" -}}
{{- end -}}
{{- $model -}}
{{- end -}}

{{- define "openshift-ai-hub.minioEndpoint" -}}
{{- $ms := .Values.modelStorage | default dict -}}
{{- $ms.endpoint | default "http://minio.industrial-edge-ml-workspace.svc:9000" -}}
{{- end -}}

{{- define "openshift-ai-hub.minioBucket" -}}
{{- $ms := .Values.modelStorage | default dict -}}
{{- $ms.bucket | default "models" -}}
{{- end -}}
