{{/*
Expand the name of the chart.
*/}}
{{- define "docker-registry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "docker-registry.fullname" -}}
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

{{- define "docker-registry.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "docker-registry.labels" -}}
helm.sh/chart: {{ include "docker-registry.chart" . }}
{{ include "docker-registry.selectorLabels" . }}
app.kubernetes.io/version: {{ include "docker-registry.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "docker-registry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "docker-registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "docker-registry.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "docker-registry.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "docker-registry.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- end }}

{{- define "docker-registry.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "docker-registry.imageTag" .) -}}
{{- end }}

{{/*
PVC name for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
*/}}
{{- define "docker-registry.claimName" -}}
{{- .p.existingClaim | default (printf "%s-%s" (include "docker-registry.fullname" .root) .name) -}}
{{- end }}

{{/*
CIFS mount options for an SMB-backed persistence entry, comma separated. Call
with (dict "root" $ "p" <entry>). smb.mountOptions when set; otherwise files are
owned by the pod's runAsUser / runAsGroup, since fsGroup is not applied to CIFS.
*/}}
{{- define "docker-registry.smbMountOptions" -}}
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
{{- define "docker-registry.volume" -}}
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
      mountOptions: {{ include "docker-registry.smbMountOptions" . | quote }}
  {{- else if .p.hostPath }}
  hostPath:
    path: {{ .p.hostPath | quote }}
    type: {{ .p.hostPathType | default "DirectoryOrCreate" }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ include "docker-registry.claimName" . }}
  {{- end }}
{{- end }}

{{/*
Pod volumes for every .Values.persistence entry.
*/}}
{{- define "docker-registry.volumes" -}}
{{- range $name, $p := .Values.persistence }}
{{ include "docker-registry.volume" (dict "root" $ "name" $name "p" $p) }}
{{- end }}
{{- end }}

{{/*
Container volumeMounts for every .Values.persistence entry.
*/}}
{{- define "docker-registry.volumeMounts" -}}
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
