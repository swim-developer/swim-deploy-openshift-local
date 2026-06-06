{{- define "ed254-consumer-validator.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/part-of: {{ .Values.appName }}
{{- end }}

{{- define "ed254-consumer-validator.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{- define "ed254-consumer-validator.validateExposure" -}}
{{- if and .Values.route.enabled .Values.ingress.enabled }}
{{- fail "Cannot enable both route and ingress. Choose one exposure method." }}
{{- end }}
{{- end }}
