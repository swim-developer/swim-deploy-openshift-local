{{- define "swim-ed254-provider.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/part-of: swim-ed254
{{- end }}

{{- define "swim-ed254-provider.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{- define "swim-ed254-provider.validateExposure" -}}
{{- if and (or .Values.route.http.enabled .Values.route.mtls.enabled) .Values.ingress.enabled }}
{{- fail "Cannot enable both route and ingress. Choose one exposure method." }}
{{- end }}
{{- end }}
