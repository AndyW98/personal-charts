{{/*
Expand the name of the chart.
*/}}
{{- define "romm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "romm.fullname" -}}
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

{{- define "romm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "romm.labels" -}}
helm.sh/chart: {{ include "romm.chart" . }}
{{ include "romm.selectorLabels" . }}
app.kubernetes.io/version: {{ include "romm.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "romm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "romm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: server
{{- end }}

{{- define "romm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "romm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "romm.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- end }}

{{- define "romm.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "romm.imageTag" .) -}}
{{- end }}

{{/*
PVC name for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
*/}}
{{- define "romm.claimName" -}}
{{- .p.existingClaim | default (printf "%s-%s" (include "romm.fullname" .root) .name) -}}
{{- end }}

{{/*
One pod volume for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
Disabled -> emptyDir; hostPath set -> hostPath; otherwise the existing or chart-managed PVC.
*/}}
{{- define "romm.volume" -}}
- name: {{ .name }}
  {{- if not .p.enabled }}
  emptyDir: {}
  {{- else if .p.hostPath }}
  hostPath:
    path: {{ .p.hostPath | quote }}
    type: {{ .p.hostPathType | default "DirectoryOrCreate" }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ include "romm.claimName" . }}
  {{- end }}
{{- end }}

{{/*
Pod volumes for every .Values.persistence entry.
*/}}
{{- define "romm.volumes" -}}
{{- range $name, $p := .Values.persistence }}
{{ include "romm.volume" (dict "root" $ "name" $name "p" $p) }}
{{- end }}
{{- end }}

{{/*
Container volumeMounts for every .Values.persistence entry.
*/}}
{{- define "romm.volumeMounts" -}}
{{- range $name, $p := .Values.persistence }}
- name: {{ $name }}
  mountPath: {{ $p.mountPath }}
  {{- with $p.subPath }}
  subPath: {{ . }}
  {{- end }}
  {{- if $p.readOnly }}
  readOnly: true
  {{- end }}
{{- end }}
{{- end }}

{{/*
Secret loaded as RomM env vars (ROMM_AUTH_SECRET_KEY, provider credentials).
*/}}
{{- define "romm.appSecretName" -}}
{{- .Values.existingSecret | default (printf "%s-app" (include "romm.fullname" .)) -}}
{{- end }}

{{- define "romm.mariadb.fullname" -}}
{{- printf "%s-mariadb" (include "romm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "romm.mariadb.secretName" -}}
{{- .Values.mariadb.auth.existingSecret | default (include "romm.mariadb.fullname" .) -}}
{{- end }}

{{- define "romm.mariadb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "romm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{- define "romm.mariadb.labels" -}}
helm.sh/chart: {{ include "romm.chart" . }}
{{ include "romm.mariadb.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.mariadb.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Database connection, from the bundled MariaDB or externalDatabase.
*/}}
{{- define "romm.db.host" -}}
{{- if .Values.mariadb.enabled }}{{ include "romm.mariadb.fullname" . }}{{ else }}{{ required "externalDatabase.host is required when mariadb.enabled is false" .Values.externalDatabase.host }}{{ end -}}
{{- end }}
{{- define "romm.db.port" -}}
{{- if .Values.mariadb.enabled }}3306{{ else }}{{ .Values.externalDatabase.port }}{{ end -}}
{{- end }}
{{- define "romm.db.name" -}}
{{- if .Values.mariadb.enabled }}{{ .Values.mariadb.auth.database }}{{ else }}{{ .Values.externalDatabase.database }}{{ end -}}
{{- end }}
{{- define "romm.db.user" -}}
{{- if .Values.mariadb.enabled }}{{ .Values.mariadb.auth.username }}{{ else }}{{ .Values.externalDatabase.username }}{{ end -}}
{{- end }}
{{- define "romm.db.secretName" -}}
{{- if .Values.mariadb.enabled }}{{ include "romm.mariadb.secretName" . }}{{ else }}{{ required "externalDatabase.existingSecret is required when mariadb.enabled is false" .Values.externalDatabase.existingSecret }}{{ end -}}
{{- end }}
{{- define "romm.db.secretKey" -}}
{{- if .Values.mariadb.enabled }}mariadb-password{{ else }}{{ .Values.externalDatabase.passwordKey }}{{ end -}}
{{- end }}
