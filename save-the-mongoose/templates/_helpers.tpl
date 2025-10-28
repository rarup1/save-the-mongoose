{{/*
Expand the name of the chart.
*/}}
{{- define "save-the-mongoose.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "save-the-mongoose.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "save-the-mongoose.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "save-the-mongoose.labels" -}}
helm.sh/chart: {{ include "save-the-mongoose.chart" . }}
{{ include "save-the-mongoose.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "save-the-mongoose.selectorLabels" -}}
app.kubernetes.io/name: {{ include "save-the-mongoose.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "save-the-mongoose.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "save-the-mongoose.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the MongoDB secret name
*/}}
{{- define "save-the-mongoose.secretName" -}}
{{- if .Values.mongodb.auth.existingSecret }}
{{- .Values.mongodb.auth.existingSecret }}
{{- else }}
{{- include "save-the-mongoose.fullname" . }}-mongodb
{{- end }}
{{- end }}

{{/*
Get the S3 secret name
*/}}
{{- define "save-the-mongoose.s3SecretName" -}}
{{- if .Values.backup.s3.existingSecret }}
{{- .Values.backup.s3.existingSecret }}
{{- else }}
{{- include "save-the-mongoose.fullname" . }}-s3
{{- end }}
{{- end }}

{{/*
Get the MongoDB connection string for replica set
*/}}
{{- define "save-the-mongoose.connectionString" -}}
{{- $fullname := include "save-the-mongoose.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $port := .Values.service.port -}}
{{- $replSetName := .Values.replication.replSetName -}}
{{- if .Values.replication.enabled }}
{{- $hosts := list -}}
{{- range $i := until (int .Values.replication.replicaCount) }}
{{- $hosts = append $hosts (printf "%s-%d.%s-headless.%s.svc.cluster.local:%d" $fullname $i $fullname $namespace (int $port)) -}}
{{- end }}
mongodb://{{ join "," $hosts }}/?replicaSet={{ $replSetName }}
{{- else }}
mongodb://{{ $fullname }}-0.{{ $fullname }}-headless.{{ $namespace }}.svc.cluster.local:{{ $port }}
{{- end }}
{{- end }}

{{/*
Get MongoDB root credentials
*/}}
{{- define "save-the-mongoose.rootUser" -}}
{{- .Values.mongodb.auth.rootUser | default "admin" }}
{{- end }}

{{/*
Generate MongoDB root password
*/}}
{{- define "save-the-mongoose.rootPassword" -}}
{{- if .Values.mongodb.auth.rootPassword }}
{{- .Values.mongodb.auth.rootPassword }}
{{- else }}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-mongodb" (include "save-the-mongoose.fullname" .)) }}
{{- if $secret }}
{{- index $secret.data "mongodb-root-password" | b64dec }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate MongoDB replica set key
*/}}
{{- define "save-the-mongoose.replicaSetKey" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-mongodb" (include "save-the-mongoose.fullname" .)) }}
{{- if $secret }}
{{- index $secret.data "mongodb-replica-set-key" | b64dec }}
{{- else }}
{{- randAlphaNum 756 }}
{{- end }}
{{- end }}

{{/*
Get the backup S3 prefix
*/}}
{{- define "save-the-mongoose.backupPrefix" -}}
{{- if .Values.backup.s3.prefix }}
{{- .Values.backup.s3.prefix }}
{{- else }}
{{- printf "release=%s/namespace=%s/" .Release.Name .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Get the replica set initialization command
*/}}
{{- define "save-the-mongoose.replicaSetInit" -}}
{{- $fullname := include "save-the-mongoose.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $port := .Values.service.port -}}
{{- $replSetName := .Values.replication.replSetName -}}
{{- $replicaCount := int .Values.replication.replicaCount -}}
mongosh --eval '
rs.initiate({
  _id: "{{ $replSetName }}",
  members: [
    {{- range $i := until $replicaCount }}
    { _id: {{ $i }}, host: "{{ $fullname }}-{{ $i }}.{{ $fullname }}-headless.{{ $namespace }}.svc.cluster.local:{{ $port }}" }{{ if ne $i (sub $replicaCount 1) }},{{ end }}
    {{- end }}
  ]
});
'
{{- end }}
