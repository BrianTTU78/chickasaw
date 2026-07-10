{{- define "cn-ecs-web-app.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "cn-ecs-web-app.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "cn-ecs-web-app.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "cn-ecs-web-app.labels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-web-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | default .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "cn-ecs-web-app.chart" . }}
{{- end }}

{{- define "cn-ecs-web-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cn-ecs-web-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
