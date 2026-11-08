{{/*
Expand the name of the chart.
*/}}
{{- define "marinara-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "marinara-engine.fullname" -}}
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

{{- define "marinara-engine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "marinara-engine.labels" -}}
helm.sh/chart: {{ include "marinara-engine.chart" . }}
{{ include "marinara-engine.selectorLabels" . }}
app.kubernetes.io/version: {{ include "marinara-engine.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "marinara-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "marinara-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "marinara-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "marinara-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image tag: explicit tag, else appVersion, plus "-<variant>" (e.g. 2.5.2-lite).
*/}}
{{- define "marinara-engine.imageTag" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- if .Values.image.variant -}}
{{- printf "%s-%s" $tag .Values.image.variant -}}
{{- else -}}
{{- $tag -}}
{{- end -}}
{{- end }}

{{- define "marinara-engine.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "marinara-engine.imageTag" .) -}}
{{- end }}

{{- define "marinara-engine.claimName" -}}
{{- .Values.persistence.existingClaim | default (printf "%s-data" (include "marinara-engine.fullname" .)) -}}
{{- end }}

{{/*
Hostnames accepted by Marinara's Host-header check: configured + ingress hosts.
*/}}
{{- define "marinara-engine.trustedHosts" -}}
{{- $hosts := list -}}
{{- range .Values.config.trustedHosts }}{{ $hosts = append $hosts . }}{{ end -}}
{{- if .Values.ingress.enabled -}}
{{- range .Values.ingress.hosts }}{{ $hosts = append $hosts .host }}{{ end -}}
{{- end -}}
{{- $hosts | uniq | join "," -}}
{{- end }}

{{/*
Browser origins trusted for CSRF: configured + ingress hosts (https when in ingress TLS).
*/}}
{{- define "marinara-engine.csrfTrustedOrigins" -}}
{{- $origins := list -}}
{{- range .Values.config.csrfTrustedOrigins }}{{ $origins = append $origins . }}{{ end -}}
{{- if .Values.ingress.enabled -}}
{{- $tlsHosts := list -}}
{{- range .Values.ingress.tls }}{{ $tlsHosts = concat $tlsHosts (.hosts | default list) }}{{ end -}}
{{- range .Values.ingress.hosts -}}
{{- $scheme := ternary "https" "http" (has .host $tlsHosts) -}}
{{- $origins = append $origins (printf "%s://%s" $scheme .host) -}}
{{- end -}}
{{- end -}}
{{- $origins | uniq | join "," -}}
{{- end }}
