{{/* vim: set filetype=mustache: */}}
{{/*
Determine external IP:
This will do the following:
1. Check for Legacy SCF Config format
2. Check for Metrics specific External IP
3. Check for New SCf Config format
4. Check for new Metrics External IPS
*/}}
{{- define "service.externalIPs" -}}
{{- if .Values.kube.external_ip -}}
{{- printf "\n - %s" .Values.kube.external_ip | indent 2 -}}
{{- else if .Values.metrics.externalIP -}}
{{- printf "\n - %s" .Values.metrics.externalIP | indent 2 -}}
{{- else if .Values.kube.external_ips -}}
{{- range .Values.kube.external_ips -}}
{{ printf "\n- %s" . | indent 4 -}}
{{- end -}}
{{- else if .Values.metrics.service.externalIPs -}}
{{- range .Values.metrics.service.externalIPs -}}
{{ printf "\n- %s" . | indent 4 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
UAA Client Secret
*/}}
{{- define "uaaClientSecret" -}}
{{- if .Values.env.UAA_ADMIN_CLIENT_SECRET -}}
{{- .Values.env.UAA_ADMIN_CLIENT_SECRET }}
{{- else if and .Values.secrets .Values.secrets.UAA_ADMIN_CLIENT_SECRET -}}
{{- .Values.secrets.UAA_ADMIN_CLIENT_SECRET }}
{{- else -}}
{{- .Values.firehoseExporter.uaa.admin.clientSecret }}
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
{{- printf "%s" .Values.metrics.service.type -}}
{{- end -}}
{{- end -}}

{{/*
Service port:
*/}}
{{- define "service.servicePort" -}}
{{- if and .Values.kube.external_ips .Values.kube.external_metrics_port -}}
{{ printf "%v" .Values.kube.external_metrics_port }}
{{- else -}}
{{ .Values.metrics.service.servicePort }}
{{- end -}}
{{- end -}}
