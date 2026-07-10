{{- define "cn-ecs-chokwaa-app.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "cn-ecs-chokwaa-app.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "cn-ecs-chokwaa-app.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "cn-ecs-chokwaa-app.labels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-chokwaa-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | default .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "cn-ecs-chokwaa-app.chart" . }}
{{- end }}

{{- define "cn-ecs-chokwaa-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-chokwaa-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
