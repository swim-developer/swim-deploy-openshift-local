{{- define "swim-ed254-provider-validator.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/component: ed254-provider-validator
app.kubernetes.io/part-of: swim-ed254
{{- end }}

{{- define "swim-ed254-provider-validator.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{- define "swim-ed254-provider-validator.validateExposure" -}}
{{- if and .Values.route.enabled .Values.ingress.enabled }}
{{- fail "Cannot enable both route and ingress. Choose one exposure method." }}
{{- end }}
{{- end }}
