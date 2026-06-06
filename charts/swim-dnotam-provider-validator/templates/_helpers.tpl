{{- define "swim-dnotam-provider-validator.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/component: dnotam-provider-validator
app.kubernetes.io/part-of: swim-dnotam
{{- end }}

{{- define "swim-dnotam-provider-validator.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{- define "swim-dnotam-provider-validator.validateExposure" -}}
{{- if and .Values.route.enabled .Values.ingress.enabled }}
{{- fail "Cannot enable both route and ingress. Choose one exposure method." }}
{{- end }}
{{- end }}
