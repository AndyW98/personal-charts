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
{{- range (include "marinara-engine.ingressTls" . | fromYamlArray) }}{{ $tlsHosts = concat $tlsHosts (.hosts | default list) }}{{ end -}}
{{- range .Values.ingress.hosts -}}
{{- $scheme := ternary "https" "http" (has .host $tlsHosts) -}}
{{- $origins = append $origins (printf "%s://%s" $scheme .host) -}}
{{- end -}}
{{- end -}}
{{- $origins | uniq | join "," -}}
{{- end }}

{{/*
Effective ingress TLS entries: ingress.tls, or one entry for all ingress hosts
when ingress.certManager is enabled and ingress.tls is empty.
*/}}
{{- define "marinara-engine.ingressTls" -}}
{{- $tls := .Values.ingress.tls | default list -}}
{{- if and .Values.ingress.certManager.enabled (not $tls) -}}
{{- $hosts := list -}}
{{- range .Values.ingress.hosts }}{{ $hosts = append $hosts .host }}{{ end -}}
{{- $secretName := .Values.ingress.certManager.secretName | default (printf "%s-ingress-tls" (include "marinara-engine.fullname" .)) -}}
{{- $tls = list (dict "secretName" $secretName "hosts" ($hosts | uniq)) -}}
{{- end -}}
{{- toYaml $tls -}}
{{- end }}

{{/*
Built-in TLS certificate Secret name.
*/}}
{{- define "marinara-engine.tlsSecretName" -}}
{{- .Values.tls.existingSecret | default (printf "%s-server-tls" (include "marinara-engine.fullname" .)) -}}
{{- end }}

{{/*
DNS names for the built-in TLS certificate: Service names, ingress hosts, extras.
*/}}
{{- define "marinara-engine.tlsDnsNames" -}}
{{- $fullName := include "marinara-engine.fullname" . -}}
{{- $ns := .Release.Namespace -}}
{{- $names := list $fullName (printf "%s.%s" $fullName $ns) (printf "%s.%s.svc" $fullName $ns) (printf "%s.%s.svc.cluster.local" $fullName $ns) -}}
{{- if .Values.ingress.enabled -}}
{{- range .Values.ingress.hosts }}{{ $names = append $names .host }}{{ end -}}
{{- end -}}
{{- $names = concat $names (.Values.tls.dnsNames | default list) -}}
{{- toYaml ($names | uniq) -}}
{{- end }}

{{/*
Container port name: "https" when Marinara serves TLS itself.
*/}}
{{- define "marinara-engine.portName" -}}
{{- if .Values.tls.enabled }}https{{ else }}http{{ end -}}
{{- end }}

{{/*
Render a probe, switching httpGet probes to HTTPS when built-in TLS is on.
*/}}
{{- define "marinara-engine.probe" -}}
{{- $probe := deepCopy .probe -}}
{{- if and .root.Values.tls.enabled $probe.httpGet -}}
{{- $_ := set $probe.httpGet "scheme" "HTTPS" -}}
{{- if eq (toString $probe.httpGet.port) "http" }}{{ $_ := set $probe.httpGet "port" "https" }}{{ end -}}
{{- end -}}
{{- toYaml $probe -}}
{{- end }}

{{/*
Reuse a key of an existing Secret (so generated values survive upgrades), else
return the given default. Usage: include "marinara-engine.secretValue" (list $ "name" "key" "default")
*/}}
{{- define "marinara-engine.secretValue" -}}
{{- $root := index . 0 -}}
{{- $existing := lookup "v1" "Secret" $root.Release.Namespace (index . 1) -}}
{{- if and $existing $existing.data (hasKey $existing.data (index . 2)) -}}
{{- index $existing.data (index . 2) -}}
{{- else -}}
{{- index . 3 | b64enc -}}
{{- end -}}
{{- end }}

{{/*
Fail fast on contradictory settings.
*/}}
{{- define "marinara-engine.validate" -}}
{{- if and .Values.envFile.content .Values.envFile.existingSecret -}}
{{- fail "envFile: set either content or existingSecret, not both" -}}
{{- end -}}
{{- if and .Values.adminSecret.generate .Values.adminSecret.existingSecret -}}
{{- fail "adminSecret: set either generate or existingSecret, not both" -}}
{{- end -}}
{{- if .Values.ingress.certManager.enabled -}}
{{- if not (.Values.ingress.certManager.clusterIssuer | default .Values.ingress.certManager.issuer) -}}
{{- fail "ingress.certManager.enabled requires ingress.certManager.clusterIssuer or ingress.certManager.issuer" -}}
{{- end -}}
{{- if and .Values.ingress.certManager.clusterIssuer .Values.ingress.certManager.issuer -}}
{{- fail "ingress.certManager: set either clusterIssuer or issuer, not both" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.tls.enabled .Values.tls.certManager.enabled -}}
{{- if .Values.tls.existingSecret -}}
{{- fail "tls: set either existingSecret or certManager.enabled, not both" -}}
{{- end -}}
{{- if not .Values.tls.certManager.issuerRef.name -}}
{{- fail "tls.certManager.enabled requires tls.certManager.issuerRef.name" -}}
{{- end -}}
{{- end -}}
{{- end }}
