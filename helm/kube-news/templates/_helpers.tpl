{{- define "kube-news.name" -}}
{{- .Chart.Name }}
{{- end }}

{{- define "kube-news.fullname" -}}
{{- .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{- define "kube-news.namespace" -}}
{{- .Chart.Name }}
{{- end }}

{{- define "kube-news.labels" -}}
app.kubernetes.io/name: {{ include "kube-news.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "kube-news.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-news.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
