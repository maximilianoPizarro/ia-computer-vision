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

{{/*
  Returns "true" or "false" for dynamic plugin disabled flag.
  Sprig default treats boolean false as empty — use kindIs to honor explicit false.
*/}}
{{- define "developer-hub.pluginDisabled" -}}
{{- $cfg := index .Values.plugins .plugin | default dict -}}
{{- $defaultEnabled := .defaultEnabled | default true -}}
{{- if kindIs "bool" $cfg.enabled -}}
{{- if $cfg.enabled -}}false{{- else -}}true{{- end -}}
{{- else if $defaultEnabled -}}false{{- else -}}true{{- end -}}
{{- end -}}

{{/*
  Returns true when a plugin is enabled (honors explicit bool; else uses default).
  Pass dict: Values, plugin, default (optional, default true).
*/}}
{{- define "developer-hub.pluginEnabled" -}}
{{- $cfg := index .Values.plugins .plugin | default dict -}}
{{- $default := .default | default true -}}
{{- if kindIs "bool" $cfg.enabled -}}
{{- $cfg.enabled -}}
{{- else -}}
{{- $default -}}
{{- end -}}
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

{{- define "developer-hub.gitlabApiUrl" -}}
{{- printf "https://%s/api/v4" (include "developer-hub.gitlabHost" .) -}}
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

{{/*
  Load a workshop OpenAPI fragment and substitute the hub apps domain.
  Pass dict: root (chart context), file (path under chart), hub (domain string).
*/}}
{{- define "developer-hub.workshopOpenAPISpec" -}}
{{- $spec := .root.Files.Get .file -}}
{{- $spec | replace "__HUB_APPS_DOMAIN__" .hub -}}
{{- end -}}

{{/*
  OCI registry for RHDH dynamic plugins (default: Red Hat ghcr overlays).
  Override with plugins.registry to use a Quay mirror, e.g. quay.io/maximilianopizarro/rhdh-plugins.
*/}}
{{- define "developer-hub.pluginRegistry" -}}
{{- .Values.plugins.registry | default "ghcr.io/redhat-developer/rhdh-plugin-export-overlays" -}}
{{- end -}}

{{- define "developer-hub.kialiEndpoint" -}}
{{- $k := .Values.plugins.kiali | default dict -}}
{{- $k.endpoint | default (printf "https://kiali-openshift-cluster-observability-operator.%s" (include "developer-hub.clusterDomain" .)) -}}
{{- end -}}

{{/*
  Derive spoke apps domain (without apps. prefix) from OpenShift API URL.
  Input: https://api.cluster-name.example.com:6443 → cluster-name.example.com
  Used for software-template defaults; source of truth is spokeCredentials (VP Pattern CR).
*/}}
{{- define "developer-hub.spokeDomainFromApiUrl" -}}
{{- $url := . | default "" | trim -}}
{{- if $url -}}
{{- $url = regexReplaceAll "^https?://api\\." $url "" -}}
{{- $url = regexReplaceAll ":6443/?$" $url "" -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "developer-hub.spokeDomainEast" -}}
{{- $sc := .Values.spokeCredentials.clusters.east | default dict -}}
{{- $d := include "developer-hub.spokeDomainFromApiUrl" ($sc.apiUrl | default "") -}}
{{- $d | default "cluster-east.example.com" -}}
{{- end -}}

{{- define "developer-hub.spokeDomainWest" -}}
{{- $sc := .Values.spokeCredentials.clusters.west | default dict -}}
{{- $d := include "developer-hub.spokeDomainFromApiUrl" ($sc.apiUrl | default "") -}}
{{- $d | default "cluster-west.example.com" -}}
{{- end -}}
