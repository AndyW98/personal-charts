{{/*
Expand the name of the chart.
*/}}
{{- define "olah.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "olah.fullname" -}}
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

{{- define "olah.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "olah.labels" -}}
helm.sh/chart: {{ include "olah.chart" . }}
{{ include "olah.selectorLabels" . }}
app.kubernetes.io/version: {{ include "olah.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "olah.selectorLabels" -}}
app.kubernetes.io/name: {{ include "olah.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "olah.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "olah.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "olah.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- end }}

{{- define "olah.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "olah.imageTag" .) -}}
{{- end }}

{{/*
PVC name for a persistence entry. Call with (dict "root" $ "name" <key> "p" <entry>).
*/}}
{{- define "olah.claimName" -}}
{{- .p.existingClaim | default (printf "%s-%s" (include "olah.fullname" .root) .name) -}}
{{- end }}

{{/*
CIFS mount options for an SMB-backed persistence entry, comma separated. Call
with (dict "root" $ "p" <entry>). smb.mountOptions when set; otherwise files are
owned by the pod's runAsUser / runAsGroup, since fsGroup is not applied to CIFS.
*/}}
{{- define "olah.smbMountOptions" -}}
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
{{- define "olah.volume" -}}
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
      mountOptions: {{ include "olah.smbMountOptions" . | quote }}
  {{- else if .p.hostPath }}
  hostPath:
    path: {{ .p.hostPath | quote }}
    type: {{ .p.hostPathType | default "DirectoryOrCreate" }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ include "olah.claimName" . }}
  {{- end }}
{{- end }}

{{/*
Pod volumes for every .Values.persistence entry.
*/}}
{{- define "olah.volumes" -}}
{{- range $name, $p := .Values.persistence }}
{{ include "olah.volume" (dict "root" $ "name" $name "p" $p) }}
{{- end }}
{{- end }}

{{/*
Container volumeMounts for every .Values.persistence entry.
*/}}
{{- define "olah.volumeMounts" -}}
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
Scheme and host[:port] clients reach the mirror at: mirror.* when set, else the
first ingress host, else the in-cluster Service.
*/}}
{{- define "olah.mirrorScheme" -}}
{{- if .Values.mirror.scheme -}}
{{- .Values.mirror.scheme -}}
{{- else if and .Values.ingress.enabled .Values.ingress.tls -}}
https
{{- else -}}
http
{{- end -}}
{{- end }}

{{- define "olah.mirrorNetloc" -}}
{{- $host := "" -}}
{{- if .Values.ingress.enabled -}}
{{- range .Values.ingress.hosts -}}
{{- if and (not $host) .host -}}
{{- $host = .host -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if .Values.mirror.netloc -}}
{{- .Values.mirror.netloc -}}
{{- else if $host -}}
{{- $host -}}
{{- else -}}
{{- printf "%s.%s.svc:%v" (include "olah.fullname" .) .Release.Namespace .Values.service.port -}}
{{- end -}}
{{- end }}

{{/*
One TOML value: strings quoted, booleans bare, numbers as integers.
*/}}
{{- define "olah.tomlValue" -}}
{{- if kindIs "string" . -}}
{{- . | quote -}}
{{- else if kindIs "bool" . -}}
{{- . -}}
{{- else -}}
{{- . | int64 -}}
{{- end -}}
{{- end }}

{{/*
[[accessibility.<kind>]] tables. Call with (dict "kind" "proxy" "rules" <list>).
*/}}
{{- define "olah.rules" -}}
{{- range .rules }}

[[accessibility.{{ $.kind }}]]
repo = {{ required (printf "config.%s: every rule needs a repo" $.kind) .repo | quote }}
allow = {{ .allow | default false }}
use_re = {{ .use_re | default false }}
{{- end }}
{{- end }}

{{/*
configs.toml
*/}}
{{- define "olah.config" -}}
{{- $c := .Values.config -}}
{{- $limit := $c.cacheSizeLimit | default "" | toString -}}
{{- if and $limit (not (regexMatch "^[0-9]+(?i:K|M|G|T|KB|MB|GB|TB)?$" $limit)) -}}
{{- fail (printf "config.cacheSizeLimit %q is not a size like 80GB or 2TB (units K, M, G, T, KB, MB, GB, TB)" $limit) -}}
{{- end -}}
[basic]
host = "0.0.0.0"
port = 8090
repos-path = {{ .Values.persistence.repos.mountPath | quote }}
mirrors-path = [{{ .Values.persistence.mirrors.mountPath | quote }}]
cache-size-limit = {{ $limit | quote }}
cache-clean-strategy = {{ $c.cacheCleanStrategy | quote }}
cache-compression = {{ $c.cacheCompression | quote }}
metadata-cache-ttl = {{ $c.metadataCacheTtl | int64 }}
xet-passthrough = {{ $c.xetPassthrough | default false }}
xet-passthrough-min-size = {{ $c.xetPassthroughMinSize | toString | quote }}
hf-scheme = {{ $c.hfScheme | quote }}
hf-netloc = {{ $c.hfNetloc | quote }}
hf-lfs-netloc = {{ $c.hfLfsNetloc | quote }}
mirror-scheme = {{ include "olah.mirrorScheme" . | quote }}
mirror-netloc = {{ include "olah.mirrorNetloc" . | quote }}
mirror-lfs-netloc = {{ include "olah.mirrorNetloc" . | quote }}
{{- range $key, $value := $c.extra }}
{{ $key }} = {{ include "olah.tomlValue" $value }}
{{- end }}

[accessibility]
offline = {{ $c.offline | default false }}
{{- include "olah.rules" (dict "kind" "proxy" "rules" $c.proxy) }}
{{- include "olah.rules" (dict "kind" "cache" "rules" $c.cache) }}
{{- end }}
