{{- define "swim-dnotam-provider.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/part-of: swim-dnotam
{{- end }}

{{- define "swim-dnotam-provider.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{- define "swim-dnotam-provider.validateExposure" -}}
{{- if and .Values.route.enabled .Values.ingress.enabled }}
{{- fail "Cannot enable both route and ingress. Choose one exposure method." }}
{{- end }}
{{- end }}
