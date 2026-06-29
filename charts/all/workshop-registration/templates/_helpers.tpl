{{/*
  Resolve apps ingress domain from VP global values or explicit override.
*/}}
{{- define "workshop-registration.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "workshop-registration.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "workshop-registration.clusterDomain" .) -}}
{{- end -}}

{{- define "workshop-registration.showroomUrl" -}}
{{- .Values.showroom.url | default (printf "https://showroom-showroom.%s" (include "workshop-registration.hubClusterDomain" .)) -}}
{{- end -}}

{{- define "workshop-registration.keycloakUrl" -}}
{{- .Values.keycloak.url | default (printf "https://sso.%s" (include "workshop-registration.clusterDomain" .)) -}}
{{- end -}}
