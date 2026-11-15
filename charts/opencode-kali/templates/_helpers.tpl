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

{{/*
CIFS mount options for an SMB-backed data volume, comma separated:
persistence.smb.mountOptions when set; otherwise files are owned by the pod's
runAsUser / runAsGroup, since fsGroup is not applied to CIFS.
*/}}
{{- define "opencode-kali.smbMountOptions" -}}
{{- $smb := .Values.persistence.smb | default dict -}}
{{- if $smb.mountOptions -}}
{{- join "," $smb.mountOptions -}}
{{- else -}}
{{- $sc := .Values.podSecurityContext | default dict -}}
{{- $opts := list -}}
{{- if hasKey $sc "runAsUser" -}}
{{- $opts = append $opts (printf "uid=%d" (int64 $sc.runAsUser)) -}}
{{- end -}}
{{- if hasKey $sc "runAsGroup" -}}
{{- $opts = append $opts (printf "gid=%d" (int64 $sc.runAsGroup)) -}}
{{- end -}}
{{- join "," (concat $opts (list "dir_mode=0770" "file_mode=0660")) -}}
{{- end -}}
{{- end }}
