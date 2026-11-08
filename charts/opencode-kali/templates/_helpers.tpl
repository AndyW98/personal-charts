{{/*
Expand the name of the chart.
*/}}
{{- define "opencode-kali.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opencode-kali.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "opencode-kali.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "opencode-kali.labels" -}}
helm.sh/chart: {{ include "opencode-kali.chart" . }}
{{ include "opencode-kali.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | toString | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "opencode-kali.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opencode-kali.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "opencode-kali.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "opencode-kali.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "opencode-kali.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion | toString) -}}
{{- end }}

{{- define "opencode-kali.claimName" -}}
{{- .Values.persistence.existingClaim | default (printf "%s-data" (include "opencode-kali.fullname" .)) -}}
{{- end }}
