{{- define "argentum-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "argentum-engine.fullname" -}}
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

{{/* Component resource name: <fullname>-<component>, kept under 63 chars. */}}
{{- define "argentum-engine.componentName" -}}
{{- printf "%s-%s" (include "argentum-engine.fullname" .root | trunc (int (sub 62 (len .component))) | trimSuffix "-") .component -}}
{{- end }}

{{- define "argentum-engine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "argentum-engine.labels" -}}
helm.sh/chart: {{ include "argentum-engine.chart" . }}
{{ include "argentum-engine.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "argentum-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "argentum-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Labels for a component: (dict "root" $ "component" "backend") */}}
{{- define "argentum-engine.componentLabels" -}}
{{ include "argentum-engine.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "argentum-engine.componentSelectorLabels" -}}
{{ include "argentum-engine.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "argentum-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "argentum-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Image reference: (dict "image" .Values.backend.image "root" $) -> repo:tag[@digest] */}}
{{- define "argentum-engine.image" -}}
{{- $tag := .image.tag | default .root.Chart.AppVersion | toString -}}
{{- if .image.digest -}}
{{- printf "%s:%s@%s" .image.repository $tag .image.digest -}}
{{- else -}}
{{- printf "%s:%s" .image.repository $tag -}}
{{- end -}}
{{- end }}

{{- define "argentum-engine.redisHost" -}}
{{- if .Values.redis.external.host -}}
{{- .Values.redis.external.host -}}
{{- else -}}
{{- include "argentum-engine.componentName" (dict "root" . "component" "redis") -}}
{{- end -}}
{{- end }}

{{- define "argentum-engine.redisPort" -}}
{{- if .Values.redis.external.host -}}
{{- .Values.redis.external.port -}}
{{- else -}}
6379
{{- end -}}
{{- end }}

{{/* Public URL: accounts.baseUrl, else the first ingress host. */}}
{{- define "argentum-engine.baseUrl" -}}
{{- if .Values.accounts.baseUrl -}}
{{- .Values.accounts.baseUrl -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- printf "%s://%s" (ternary "https" "http" (not (empty .Values.ingress.tls))) (index .Values.ingress.hosts 0).host -}}
{{- end -}}
{{- end }}
