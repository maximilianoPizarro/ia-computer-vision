{{/*
  Resolve apps ingress domain from VP global values or explicit override.
*/}}
{{- define "showroom.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "showroom.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "showroom.clusterDomain" .) -}}
{{- end -}}

{{- define "showroom.clusterDomainBase" -}}
{{- $d := include "showroom.hubClusterDomain" . -}}
{{- if hasPrefix "apps." $d -}}
{{- trimPrefix "apps." $d -}}
{{- else -}}
{{- $d -}}
{{- end -}}
{{- end -}}

{{- define "showroom.hubApiUrl" -}}
{{- printf "https://api.%s:6443" (include "showroom.clusterDomainBase" .) -}}
{{- end -}}

{{/*
  Derive spoke cluster domain from OpenShift API URL.
  https://api.cluster-name.example.com:6443 → cluster-name.example.com
*/}}
{{- define "showroom.spokeDomainFromApiUrl" -}}
{{- $url := . | default "" | trim -}}
{{- if $url -}}
{{- $url = regexReplaceAll "^https?://api\\." $url "" -}}
{{- $url = regexReplaceAll ":6443/?$" $url "" -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "showroom.eastApiUrl" -}}
{{- $sc := .Values.spokeCredentials.clusters.east | default dict -}}
{{- $url := .Values.clusters.east.apiUrl | default $sc.apiUrl | default "" -}}
{{- if not $url -}}
{{- $sec := lookup "v1" "Secret" "openshift-gitops" "spoke-credentials" -}}
{{- if $sec -}}
{{- $url = index $sec.data "east-api-url" | default "" | b64dec -}}
{{- end -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "showroom.westApiUrl" -}}
{{- $sc := .Values.spokeCredentials.clusters.west | default dict -}}
{{- $url := .Values.clusters.west.apiUrl | default $sc.apiUrl | default "" -}}
{{- if not $url -}}
{{- $sec := lookup "v1" "Secret" "openshift-gitops" "spoke-credentials" -}}
{{- if $sec -}}
{{- $url = index $sec.data "west-api-url" | default "" | b64dec -}}
{{- end -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "showroom.eastDomain" -}}
{{- $explicit := .Values.clusters.east.domain | default "" -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else -}}
{{- include "showroom.spokeDomainFromApiUrl" (include "showroom.eastApiUrl" .) -}}
{{- end -}}
{{- end -}}

{{- define "showroom.westDomain" -}}
{{- $explicit := .Values.clusters.west.domain | default "" -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else -}}
{{- include "showroom.spokeDomainFromApiUrl" (include "showroom.westApiUrl" .) -}}
{{- end -}}
{{- end -}}
