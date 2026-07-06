{{- define "rhbk-iam.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- /*
keycloak.ssoHost (full hostname) wins if set for back-compat; otherwise
build from keycloak.ssoHostPrefix (portable across clusters/domains --
values-hub-rhpds.yaml overrides just the prefix, e.g. "rhdh-sso", when the
default "sso" collides with a pre-existing, unrelated Route on RHPDS
sandboxes). Keep in sync with the SAME prefix override on every other
chart that references this pattern's shared SSO hostname: developer-hub
(route owner), neuroface-gateway, workshop-registration, devspaces,
console-links.
*/ -}}
{{- define "rhbk-iam.ssoHost" -}}
{{- .Values.keycloak.ssoHost | default (printf "%s.%s" (.Values.keycloak.ssoHostPrefix | default "sso") (include "rhbk-iam.clusterDomain" .)) -}}
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
