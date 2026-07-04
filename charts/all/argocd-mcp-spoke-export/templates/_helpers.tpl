{{- define "argocd-mcp-spoke-export.argoNamespace" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.argoNamespace | default $g.vpArgoNamespace | default $g.argoNamespace | default "vp-gitops" -}}
{{- end -}}
