{{/*
Volledige naam van de applicatie, gebaseerd op de release naam
*/}}
{{- define "aks-demo-app.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{/*
Standaard labels die op alle resources worden gezet
*/}}
{{- define "aks-demo-app.labels" -}}
app: {{ include "aks-demo-app.fullname" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}