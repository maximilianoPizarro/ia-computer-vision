{{/*
  True when east or west token is set via Helm values (sandbox override).
  Activates the direct ManagedCluster+auto-import-secret template path.
*/}}
{{- define "acm-hub-spoke.useHelmTokens" -}}
{{- $mc := .Values.managedClusters | default dict -}}
{{- if or (get (index $mc "east" | default dict) "token") (get (index $mc "west" | default dict) "token") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
  Effective spoke-credentials mode: vault | inline | secret | helm.
  Returns "helm" when managedClusters tokens are set (overrides any mode).
*/}}
{{- define "acm-hub-spoke.spokeCredMode" -}}
{{- if eq (include "acm-hub-spoke.useHelmTokens" .) "true" -}}
helm
{{- else -}}
{{- .Values.spokeCredentials.mode | default "vault" -}}
{{- end -}}
{{- end -}}

{{/*
  True when the CronJob-based import path should render
  (any mode except helm and disabled).
*/}}
{{- define "acm-hub-spoke.useCronJob" -}}
{{- $mode := include "acm-hub-spoke.spokeCredMode" . -}}
{{- if and .Values.spokeCredentials.enabled (ne $mode "helm") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
  Vault KV path for spoke-credentials (VP hub mount).
*/}}
{{- define "acm-hub-spoke.spokeCredentialsVaultKey" -}}
{{- .Values.spokeCredentials.vaultKey | default "secret/data/hub/spoke-credentials" -}}
{{- end -}}

{{/*
  ESO secret store reference from global VP values.
*/}}
{{- define "acm-hub-spoke.secretStoreRef" -}}
{{- $g := .Values.global | default dict -}}
{{- $ss := $g.secretStore | default dict -}}
name: {{ $ss.name | default "vault-backend" }}
kind: {{ $ss.kind | default "ClusterSecretStore" }}
{{- end -}}
