{{/*
  Resolve apps ingress domain from VP global values or explicit override.
*/}}
{{- define "models-as-a-service.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.hubClusterDomain | default $g.localClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "models-as-a-service.maasHostname" -}}
{{- printf "%s.%s" (.Values.gateway.hostnamePrefix | default "maas") (include "models-as-a-service.clusterDomain" .) -}}
{{- end -}}

{{- define "models-as-a-service.modelResourceName" -}}
{{- . | replace "." "-" -}}
{{- end -}}

{{/*
  Shared by authorino-tls-env Job + CronJob: build a CA bundle Authorino can
  use for OIDC discovery to https://sso.<apps>/ (router-ca) and in-cluster
  mTLS (service-ca), mount it at the SSL_CERT_FILE path Kuadrant expects,
  and keep Deployment env in sync.
*/}}
{{- define "models-as-a-service.authorinoTlsEnvScript" -}}
{{- $auth := .Values.authorino | default dict -}}
set -euo pipefail
DEPLOY_NAME="{{ $auth.deploymentName | default "authorino" }}"
PREFERRED_NS="{{ $auth.deploymentNamespace | default "kuadrant-system" }}"
CANDIDATES="${PREFERRED_NS} kuadrant-system redhat-connectivity-link-operator"
CA_PATH=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt
CM_NAME=authorino-trusted-ca

echo "Waiting for Deployment/${DEPLOY_NAME} (Authorino)..."
FOUND_NS=""
for i in $(seq 1 60); do
  for ns in ${CANDIDATES}; do
    if oc get "deployment/${DEPLOY_NAME}" -n "${ns}" >/dev/null 2>&1; then
      FOUND_NS="${ns}"
      break 2
    fi
  done
  echo "  attempt ${i}/60: not found yet"
  sleep 10
done
if [ -z "${FOUND_NS}" ]; then
  echo "ERROR: deployment/${DEPLOY_NAME} not found in: ${CANDIDATES}"
  exit 1
fi
echo "Found Authorino in ${FOUND_NS}"

BUNDLE=/tmp/authorino-ca-bundle.crt
: > "${BUNDLE}"
if [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then
  cat /etc/pki/tls/certs/ca-bundle.crt >> "${BUNDLE}"
elif [ -f /etc/ssl/certs/ca-bundle.crt ]; then
  cat /etc/ssl/certs/ca-bundle.crt >> "${BUNDLE}"
fi
printf '\n' >> "${BUNDLE}"

if oc get secret router-ca -n openshift-ingress-operator >/dev/null 2>&1; then
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d >> "${BUNDLE}"
  printf '\n' >> "${BUNDLE}"
  echo "Appended router-ca (ingress)"
else
  echo "WARN: secret router-ca not found in openshift-ingress-operator"
fi

if oc get configmap openshift-service-ca.crt -n openshift-config-managed >/dev/null 2>&1; then
  oc get configmap openshift-service-ca.crt -n openshift-config-managed \
    -o jsonpath='{.data.service-ca\.crt}' >> "${BUNDLE}"
  printf '\n' >> "${BUNDLE}"
  echo "Appended openshift-service-ca"
fi

oc create configmap "${CM_NAME}" -n "${FOUND_NS}" \
  --from-file=service-ca-bundle.crt="${BUNDLE}" \
  --dry-run=client -o yaml | oc apply -f -

if oc get authorino authorino -n "${FOUND_NS}" >/dev/null 2>&1; then
  oc patch authorino authorino -n "${FOUND_NS}" --type=merge -p "{
    \"spec\": {
      \"volumes\": {
        \"items\": [
          {
            \"name\": \"trusted-ca\",
            \"mountPath\": \"/etc/ssl/certs/openshift-service-ca\",
            \"configMaps\": [\"${CM_NAME}\"],
            \"items\": [{\"key\": \"service-ca-bundle.crt\", \"path\": \"service-ca-bundle.crt\"}]
          }
        ]
      }
    }
  }"
  echo "Patched Authorino CR volumes"
else
  echo "WARN: Authorino CR not found in ${FOUND_NS}"
fi

echo "Setting Authorino TLS env vars on deployment/${DEPLOY_NAME} in ${FOUND_NS}..."
oc set env "deployment/${DEPLOY_NAME}" \
  -n "${FOUND_NS}" \
  SSL_CERT_FILE="${CA_PATH}" \
  REQUESTS_CA_BUNDLE="${CA_PATH}"

echo "authorino-tls-env complete."
{{- end -}}
