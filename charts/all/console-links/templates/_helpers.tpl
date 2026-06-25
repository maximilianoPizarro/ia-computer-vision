{{/*
  Per-component ConsoleLink icon as data:image/svg+xml;base64 (OpenShift ApplicationMenu).
  Icons live under files/icons/<name>.svg — regenerate with scripts/generate-console-icons.sh
*/}}
{{- define "console-links.iconURL" -}}
{{- $ctx := .root -}}
{{- $file := .icon -}}
{{- $svg := $ctx.Files.Get (printf "files/icons/%s" $file) | trim -}}
data:image/svg+xml;base64,{{ $svg | b64enc }}
{{- end -}}

{{- define "console-links.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "cluster.example.com" -}}
{{- end -}}

{{- define "console-links.domainBase" -}}
{{- $d := include "console-links.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "console-links.appsDomain" -}}
{{- printf "apps.%s" (include "console-links.domainBase" .) -}}
{{- end -}}

{{- define "console-links.hubDomainBase" -}}
{{- $g := .Values.global | default dict -}}
{{- $hub := .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "console-links.domainBase" .) -}}
{{- if hasPrefix "apps." $hub -}}
{{- trimPrefix "apps." $hub -}}
{{- else -}}
{{- $hub -}}
{{- end -}}
{{- end -}}
