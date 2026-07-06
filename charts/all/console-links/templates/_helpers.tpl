{{/*
  Per-component ConsoleLink icon as a base64 data URI (OpenShift ApplicationMenu).
  Icons live under files/icons/<name>.<ext> -- most are official brand assets
  extracted directly from the installed operator's own CSV
  (spec.icon[0].base64data / spec.icon[0].mediatype via `oc get csv`), not
  third-party redraws, so the mediatype must match the source file's real
  format (PNG for most Red Hat product icons, SVG for a few). Detect it from
  the file extension instead of hardcoding image/svg+xml -- base64-encoding
  PNG bytes and mislabeling them as image/svg+xml renders as a broken image.
*/}}
{{- define "console-links.iconURL" -}}
{{- $ctx := .root -}}
{{- $file := .icon -}}
{{- $mediatype := "image/svg+xml" -}}
{{- if hasSuffix ".png" $file -}}
{{- $mediatype = "image/png" -}}
{{- end -}}
{{- $data := $ctx.Files.Get (printf "files/icons/%s" $file) -}}
{{- if hasSuffix ".svg" $file -}}
{{- $data = trim $data -}}
{{- end -}}
data:{{ $mediatype }};base64,{{ $data | b64enc }}
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
