{{/*
  True when east or west token is set via Helm values (sandbox override).
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
  Vault KV path for spoke-credentials (VP hub mount).
*/}}
{{- define "acm-hub-spoke.spokeCredentialsVaultKey" -}}
{{- .Values.spokeCredentials.vaultKey | default "secret/data/hub/spoke-credentials" -}}
{{- end -}}

{{/*
  ESO secret store reference from global VP values.
*/}}
{{- define "acm-hub-spoke.secretStoreRef" -}}
{{- $ss := .Values.global.secretStore | default dict -}}
name: {{ $ss.name | default "vault-backend" }}
kind: {{ $ss.kind | default "ClusterSecretStore" }}
{{- end -}}
