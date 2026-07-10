{{- define "cn-ecs-data-platform.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "cn-ecs-data-platform.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "cn-ecs-data-platform.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "cn-ecs-data-platform.labels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-data-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | default .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "cn-ecs-data-platform.chart" . }}
{{- end }}

{{- define "cn-ecs-data-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-data-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
