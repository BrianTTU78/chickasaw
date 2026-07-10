{{- define "formio.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "formio.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "formio.labels" -}}
app.kubernetes.io/name: {{ include "formio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}