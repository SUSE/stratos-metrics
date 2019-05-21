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
{{- define "nginx.credentials-username" -}}
{{- if .Values.nginx.username -}}
{{- .Values.nginx.username -}}
{{- else -}}
{{- .Values.metrics.username -}}
{{- end -}}
{{- end -}}

{{/*
Metrics Credentials - Password
*/}}
{{- define "nginx.credentials-password" -}}
{{- if .Values.nginx.username -}}
{{- .Values.nginx.password -}}
{{- else -}}
{{- .Values.metrics.password -}}
{{- end -}}
{{- end -}}
