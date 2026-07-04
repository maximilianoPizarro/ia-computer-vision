{{- define "openshift-lightspeed.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.hubClusterDomain | default $g.localClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "openshift-lightspeed.aiGatewayUrl" -}}
{{- .Values.llm.url | default (printf "https://ai-gateway.%s/v1" (include "openshift-lightspeed.clusterDomain" .)) -}}
{{- end -}}
