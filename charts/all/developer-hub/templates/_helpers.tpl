{{/*
  OpenAI-compatible base URL for Llama Stack vLLM provider (strip /v1/chat/completions).
*/}}
{{- define "developer-hub.vllmBaseUrl" -}}
{{- $url := .apiURL | default "" -}}
{{- $url = regexReplaceAll "/chat/completions/?$" $url "" -}}
{{- if not (hasSuffix "/v1" $url) -}}
{{- $url = printf "%s/v1" (trimSuffix "/" $url) -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "developer-hub.lightspeedEnabled" -}}
{{- if .Values.plugins.lightspeed.enabled -}}true{{- end -}}
{{- end -}}

{{- define "developer-hub.lightspeedAiModel" -}}
{{- $ls := .Values.plugins.lightspeed | default dict -}}
{{- $ai := $ls.aiModel | default dict -}}
{{- if not $ai.apiURL -}}
{{- $ai = mergeOverwrite (dict) (.Values.aiModel | default dict) $ai -}}
{{- end -}}
{{- $ai | toJson -}}
{{- end -}}

{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "developer-hub.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "developer-hub.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "developer-hub.clusterDomain" .) -}}
{{- end -}}

{{- define "developer-hub.clusterDomainBase" -}}
{{- $d := include "developer-hub.clusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "developer-hub.gitlabHost" -}}
{{- printf "gitlab.apps.%s" (include "developer-hub.clusterDomainBase" .) -}}
{{- end -}}

{{- define "developer-hub.platformContentBaseUrl" -}}
{{- printf "https://%s/developer-hub/platform-content" (include "developer-hub.gitlabHost" .) -}}
{{- end -}}

{{- define "developer-hub.keycloakNamespace" -}}
{{- .Values.keycloak.namespace | default "keycloak-system" -}}
{{- end -}}

{{- define "developer-hub.keycloakCrName" -}}
{{- .Values.keycloak.crName | default "keycloak" -}}
{{- end -}}

{{- define "developer-hub.keycloakServiceName" -}}
{{- .Values.keycloak.serviceName | default "keycloak-service-serving" -}}
{{- end -}}

{{- define "developer-hub.ssoHost" -}}
{{- printf "sso.%s" (include "developer-hub.clusterDomain" .) -}}
{{- end -}}

{{- define "developer-hub.ssoBaseUrl" -}}
{{- printf "https://%s" (include "developer-hub.ssoHost" .) -}}
{{- end -}}

{{- define "developer-hub.oidcDiscoveryUrl" -}}
{{- printf "%s/realms/backstage/.well-known/openid-configuration" (include "developer-hub.ssoBaseUrl" .) -}}
{{- end -}}

{{- define "developer-hub.oidcAuthVaultKey" -}}
{{- $oa := .Values.oidcAuth | default dict -}}
{{- $oa.vaultKey | default "secret/data/hub/developer-hub-secrets" -}}
{{- end -}}
