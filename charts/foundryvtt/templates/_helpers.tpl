{{/*
Expand the name of the chart.
*/}}
{{- define "foundryvtt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "foundryvtt.fullname" -}}
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

{{- define "foundryvtt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "foundryvtt.labels" -}}
helm.sh/chart: {{ include "foundryvtt.chart" . }}
{{ include "foundryvtt.selectorLabels" . }}
app.kubernetes.io/version: {{ include "foundryvtt.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "foundryvtt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "foundryvtt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "foundryvtt.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "foundryvtt.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "foundryvtt.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- end }}

{{- define "foundryvtt.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "foundryvtt.imageTag" .) -}}
{{- end }}

{{/*
PVC name for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
*/}}
{{- define "foundryvtt.claimName" -}}
{{- .p.existingClaim | default (printf "%s-%s" (include "foundryvtt.fullname" .root) .name) -}}
{{- end }}

{{/*
CIFS mount options for an SMB-backed persistence entry, comma separated. Call
with (dict "root" $ "p" <entry>). smb.mountOptions when set; otherwise files are
owned by the pod's runAsUser / runAsGroup, since fsGroup is not applied to CIFS.
*/}}
{{- define "foundryvtt.smbMountOptions" -}}
{{- $smb := .p.smb | default dict -}}
{{- if $smb.mountOptions -}}
{{- join "," $smb.mountOptions -}}
{{- else -}}
{{- $sc := .root.Values.podSecurityContext | default dict -}}
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

{{/*
One pod volume for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
Disabled -> emptyDir; smb.source set -> SMB share through the SMB CSI driver;
hostPath set -> hostPath; otherwise the existing or chart-managed PVC.
*/}}
{{- define "foundryvtt.volume" -}}
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
      mountOptions: {{ include "foundryvtt.smbMountOptions" . | quote }}
  {{- else if .p.hostPath }}
  hostPath:
    path: {{ .p.hostPath | quote }}
    type: {{ .p.hostPathType | default "DirectoryOrCreate" }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ include "foundryvtt.claimName" . }}
  {{- end }}
{{- end }}

{{/*
Pod volumes for every .Values.persistence entry.
*/}}
{{- define "foundryvtt.volumes" -}}
{{- range $name, $p := .Values.persistence }}
{{ include "foundryvtt.volume" (dict "root" $ "name" $name "p" $p) }}
{{- end }}
{{- end }}

{{/*
Container volumeMounts for every .Values.persistence entry.
*/}}
{{- define "foundryvtt.volumeMounts" -}}
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
