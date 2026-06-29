{{- define "rhbk-iam.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "rhbk-iam.ssoHost" -}}
{{- .Values.keycloak.ssoHost | default (printf "sso.%s" (include "rhbk-iam.clusterDomain" .)) -}}
{{- end -}}

{{- define "rhbk-iam.issuerUrl" -}}
{{- printf "https://%s/realms/" (include "rhbk-iam.ssoHost" .) -}}
{{- end -}}

{{- define "rhbk-iam.clientId" -}}
{{- printf "client-%s-user%d" .realm .userNum -}}
{{- end -}}

{{- define "rhbk-iam.groupName" -}}
{{- printf "group-user%d" .userNum -}}
{{- end -}}

{{- define "rhbk-iam.vaultKey" -}}
{{- printf "%s/%s/user%d" $.Values.vault.pathPrefix .realm .userNum -}}
{{- end -}}
