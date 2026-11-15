{{/*
Expand the name of the chart.
*/}}
{{- define "gitea.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "gitea.fullname" -}}
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

{{- define "gitea.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gitea.labels" -}}
helm.sh/chart: {{ include "gitea.chart" . }}
{{ include "gitea.selectorLabels" . }}
app.kubernetes.io/version: {{ include "gitea.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "gitea.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gitea.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "gitea.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gitea.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "gitea.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- end }}

{{- define "gitea.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "gitea.imageTag" .) -}}
{{- end }}

{{/*
PVC name for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
*/}}
{{- define "gitea.claimName" -}}
{{- .p.existingClaim | default (printf "%s-%s" (include "gitea.fullname" .root) .name) -}}
{{- end }}

{{/*
CIFS mount options for an SMB-backed persistence entry, comma separated. Call
with (dict "root" $ "p" <entry>). smb.mountOptions when set; otherwise files are
owned by env.USER_UID / env.USER_GID, the user the app runs as, since fsGroup is not applied to CIFS.
*/}}
{{- define "gitea.smbMountOptions" -}}
{{- $smb := .p.smb | default dict -}}
{{- if $smb.mountOptions -}}
{{- join "," $smb.mountOptions -}}
{{- else -}}
{{- $env := .root.Values.env | default dict -}}
{{- $opts := list -}}
{{- with $env.USER_UID -}}
{{- $opts = append $opts (printf "uid=%d" (int64 .)) -}}
{{- end -}}
{{- with $env.USER_GID -}}
{{- $opts = append $opts (printf "gid=%d" (int64 .)) -}}
{{- end -}}
{{- join "," (concat $opts (list "dir_mode=0770" "file_mode=0660")) -}}
{{- end -}}
{{- end }}

{{/*
One pod volume for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
Disabled -> emptyDir; smb.source set -> SMB share through the SMB CSI driver;
hostPath set -> hostPath; otherwise the existing or chart-managed PVC.
*/}}
{{- define "gitea.volume" -}}
{{- $smb := .p.smb | default dict -}}
{{- if and .p.enabled $smb.source (or .p.hostPath .p.existingClaim) -}}
{{- fail (printf "persistence.%s: set only one of smb.source, hostPath and existingClaim" .name) -}}
{{- end -}}
- name: {{ .name }}
  {{- if not .p.enabled }}
  emptyDir: {}
  {{- else if $smb.source }}
  csi:
    driver: smb.csi.k8s.io
    volumeAttributes:
      source: {{ $smb.source | quote }}
      {{- with $smb.existingSecret }}
      secretName: {{ . | quote }}
      {{- end }}
      mountOptions: {{ include "gitea.smbMountOptions" . | quote }}
  {{- else if .p.hostPath }}
  hostPath:
    path: {{ .p.hostPath | quote }}
    type: {{ .p.hostPathType | default "DirectoryOrCreate" }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ include "gitea.claimName" . }}
  {{- end }}
{{- end }}

{{/*
Pod volumes for every .Values.persistence entry.
*/}}
{{- define "gitea.volumes" -}}
{{- range $name, $p := .Values.persistence }}
{{ include "gitea.volume" (dict "root" $ "name" $name "p" $p) }}
{{- end }}
{{- end }}

{{/*
Container volumeMounts for every .Values.persistence entry.
*/}}
{{- define "gitea.volumeMounts" -}}
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
