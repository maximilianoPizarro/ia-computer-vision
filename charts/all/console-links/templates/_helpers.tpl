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
