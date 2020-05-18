{{/* vim: set filetype=mustache: */}}

{{/*
Determine external IPs:
This will do the following:
1. Check for Legacy SCF Config format
2. Check for Metrics specific External IP
3. Check for New SCF Config format
4. Check for new Metrics External IPS
*/}}
{{- define "service.externalIPs" -}}
{{- if .Values.kube.external_ip }}
  externalIPs:
{{- printf "\n - %s" .Values.kube.external_ip | indent 3 -}}
{{- printf "\n" -}}
{{- else if .Values.metrics.externalIP }}
  externalIPs:
{{- printf "\n - %s" .Values.metrics.externalIP | indent 3 -}}
{{- printf "\n" -}}
{{- else if .Values.kube.external_ips }}
  externalIPs:
{{- range .Values.kube.external_ips -}}
{{- printf "\n- %s" . | indent 4 -}}
{{- end -}}
{{- printf "\n" -}}
{{- else if .Values.metrics.service -}}
{{- if .Values.metrics.service.externalIPs }}
  externalIPs:
{{- range .Values.metrics.service.externalIPs -}}
{{ printf "\n- %s" . | indent 4 }}
{{- end -}}
{{- printf "\n" -}}
{{- end -}}
{{- end -}}
{{ end }}

{{/*
UAA Admin Client
*/}}
{{- define "uaaAdminClient" -}}
{{- if .Values.cloudFoundry -}}
{{- if .Values.cloudFoundry.uaaAdminClient -}}
{{- .Values.cloudFoundry.uaaAdminClient }}
{{- else -}}
{{- template "defaultUaaAdminClient" . }}
{{- end -}}
{{- else -}}
{{- template "defaultUaaAdminClient" . }}
{{- end -}}
{{- end -}}


{{/*
UAA Admin Client
*/}}
{{- define "defaultUaaAdminClient" -}}
{{- if .Values.firehoseExporter.uaa -}}
{{- if .Values.firehoseExporter.uaa.admin -}}
{{- .Values.firehoseExporter.uaa.admin.client }}
{{- else -}}
admin
{{- end -}}
{{- else -}}
admin
{{- end -}}
{{- end -}}


{{/*
UAA Admin Client Secret
*/}}
{{- define "uaaAdminClientSecret" -}}
{{- if .Values.cloudFoundry -}}
{{- if .Values.cloudFoundry.uaaAdminClientSecret -}}
{{- .Values.cloudFoundry.uaaAdminClientSecret }}
{{- else -}}
{{- template "defaultUaaAdminClientSecret" . }}
{{- end -}}
{{- else -}}
{{- template "defaultUaaAdminClientSecret" . }}
{{- end -}}
{{- end -}}


{{/*
UAA Admin Client Secret
*/}}
{{- define "defaultUaaAdminClientSecret" -}}
{{- if .Values.env.UAA_ADMIN_CLIENT_SECRET -}}
{{- .Values.env.UAA_ADMIN_CLIENT_SECRET }}
{{- else if and .Values.secrets .Values.secrets.UAA_ADMIN_CLIENT_SECRET -}}
{{- .Values.secrets.UAA_ADMIN_CLIENT_SECRET }}
{{- else -}}
{{- if .Values.firehoseExporter.uaa.admin -}}
{{- .Values.firehoseExporter.uaa.admin.clientSecret }}
{{- else -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
UAA Admin / CF Skip SSL Validation
*/}}
{{- define "uaaSkipSslVerification" -}}

{{- if .Values.cloudFoundry -}}
{{- if .Values.cloudFoundry.skipSslVerification -}}
{{- .Values.cloudFoundry.skipSslVerification }}
{{- else -}}
{{- .Values.firehoseExporter.uaa.skipSslVerification }}
{{- end -}}
{{- else -}}
{{- .Values.firehoseExporter.uaa.skipSslVerification }}
{{- end -}}
{{- end -}}


{{/*
Cloud Foundry API Endpoint

*/}}
{{- define "cloudFoundryApiEndpoint" -}}

{{- if .Values.cloudFoundry -}}
{{- if .Values.cloudFoundry.apiEndpoint -}}
{{- .Values.cloudFoundry.apiEndpoint }}
{{- else -}}
{{- template "defaultCloudFoundryApiEndpoint" . }}
{{- end -}}
{{- else -}}
{{- template "defaultCloudFoundryApiEndpoint" . }}
{{- end -}}
{{- end -}}

{{/*
UAA Admin Client Secret
*/}}
{{- define "defaultCloudFoundryApiEndpoint" -}}
{{- if .Values.env.DOMAIN -}}
https://api.{{- .Values.env.DOMAIN }}
{{- end -}}
{{- end -}}

{{/*
Image pull secret
*/}}
{{- define "imagePullSecret" }}
{{- printf "{\"%s\":{\"username\": \"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\": \"%s\"}}" .Values.kube.registry.hostname .Values.kube.registry.username .Values.kube.registry.password .Values.kube.registry.email (printf "%s:%s" .Values.kube.registry.username .Values.kube.registry.password | b64enc) | b64enc }}
{{- end }}

{{/*
Service type:
*/}}
{{- define "service.serviceType" -}}
{{- if or .Values.useLb .Values.services.loadbalanced -}}
LoadBalancer
{{- else -}}
{{- if .Values.metrics.service -}}
{{- default "ClusterIP" .Values.metrics.service.type -}}
{{- else -}}
ClusterIP
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Service port:
*/}}
{{- define "service.servicePort" -}}
{{- if and .Values.kube.external_ips .Values.kube.external_metrics_port -}}
{{ printf "%v" .Values.kube.external_metrics_port }}
{{- else -}}
{{- if .Values.metrics.service -}}
{{ default 443 .Values.metrics.service.servicePort}}
{{- else -}}
443
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Metrics Credentials - Username
*/}}
{{- define "nginx.credentials-username-base64" -}}
{{- if .Values.nginx.username -}}
{{- .Values.nginx.username | b64enc -}}
{{- else -}}
{{- .Values.metrics.username | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
Metrics Credentials - Password
*/}}
{{- define "nginx.credentials-password-base64" -}}
{{- if .Values.nginx.username -}}
{{- .Values.nginx.password | b64enc -}}
{{- else -}}
{{- .Values.metrics.password | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "metrics.certName" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate self-signed certificate for ingress if needed
*/}}
{{- define "metrics.generateIngressCertificate" -}}
{{- $altNames := list (printf "%s" .Values.metrics.service.ingress.host) (printf "%s.%s" (include "metrics.certName" .) .Release.Namespace ) ( printf "%s.%s.svc" (include "metrics.certName" .) .Release.Namespace ) -}}
{{- $ca := genCA "stratos-ca" 365 -}}
{{- $cert := genSignedCert ( include "metrics.certName" . ) nil $altNames 365 $ca -}}
{{- if .Values.metrics.service.ingress.tls.crt }}
  tls.crt: {{ .Values.metrics.service.ingress.tls.crt | b64enc | quote }}
{{- else }}
  tls.crt: {{ $cert.Cert | b64enc | quote }}
{{- end -}}
{{- if .Values.metrics.service.ingress.tls.key }}
  tls.key: {{ .Values.metrics.service.ingress.tls.key | b64enc | quote }}
{{- else }}
  tls.key: {{ $cert.Key | b64enc | quote }}
{{- end -}}
{{- end -}}

{{/*
Ingress Host from .Values.metrics.service
*/}}
{{- define "ingress.host.value" -}}
{{- if .Values.metrics.service -}}
{{- if .Values.metrics.service.ingress -}}
{{- if .Values.metrics.service.ingress.host -}}
{{ .Values.metrics.service.ingress.host }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Ingress Host:
*/}}
{{- define "ingress.host" -}}
{{ $host := (include "ingress.host.value" .) }}
{{- if $host -}}
{{ $host | quote }}
{{- else if .Values.env.DOMAIN -}}
{{ print "metrics." .Values.env.DOMAIN }}
{{- else -}}
{{ required "Host name is required" $host | quote }}
{{- end -}}
{{- end -}}


{{/*
Generate self-signed certificate for Metrics if needed
*/}}
{{- define "metrics.generateCertificate" -}}
{{- $altNames := list (printf "%s.%s" (include "metrics.certName" .) .Release.Namespace ) ( printf "%s.%s.svc" (include "metrics.certName" .) .Release.Namespace ) -}}
{{- $ca := genCA "stratos-ca" 365 -}}
{{- $cert := genSignedCert ( include "metrics.certName" . ) nil $altNames 365 $ca -}}
  cert.crt: {{ $cert.Cert | b64enc | quote }}
  cert.key: {{ $cert.Key | b64enc | quote }}
{{- end -}}
