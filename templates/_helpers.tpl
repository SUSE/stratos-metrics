{{/* vim: set filetype=mustache: */}}
{{/*
Determine external IP:
This will do the following:
1. Check for Legacy SCF Config format
2. Check for Metrics specific External IP
3. Check for New SCf Config format
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