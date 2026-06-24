{{- define "gitlab-operator.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- /* Strip apps. when RHDP passes localClusterDomain as apps.<cluster>.<domain> */ -}}
{{- define "gitlab-operator.clusterDomainBase" -}}
{{- $d := include "gitlab-operator.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "gitlab-operator.appsDomain" -}}
{{- printf "apps.%s" (include "gitlab-operator.clusterDomainBase" .) -}}
{{- end -}}

{{- define "gitlab-operator.host" -}}
{{- printf "gitlab.apps.%s" (include "gitlab-operator.clusterDomainBase" .) -}}
{{- end -}}

{{- define "gitlab-operator.apiUrl" -}}
{{- printf "https://%s/api/v4" (include "gitlab-operator.host" .) -}}
{{- end -}}

{{- define "gitlab-operator.webUrl" -}}
{{- printf "https://%s" (include "gitlab-operator.host" .) -}}
{{- end -}}
