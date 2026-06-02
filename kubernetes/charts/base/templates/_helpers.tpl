{{/*
base.cluster-settings — fetches the cluster-settings ConfigMap (generated from
globals.env by flux/meta/kustomization.yaml) and returns its .data as YAML.

Usage:
  {{- $clusterSettings := (include "base.cluster-settings" .) | fromYaml }}
  value: {{ $clusterSettings.KGATEWAY_EXTERNAL_LB_IP }}

Caveats (helm lookup):
- Returns empty during `helm template`, `--dry-run`, and `flate build hr`
  (no cluster context). At Flux apply time the helm-controller has cluster
  access, so this resolves correctly in-cluster.
- The ConfigMap must already exist when the chart renders. flux-meta is a
  dependsOn for home-apps so this holds on bootstrap.
*/}}
{{- define "base.cluster-settings" -}}
{{- $cm := lookup "v1" "ConfigMap" "flux-system" "cluster-settings" -}}
{{- if and $cm $cm.data -}}
{{- $cm.data | toYaml -}}
{{- end -}}
{{- end -}}

{{/* CNPG resource naming — all derive from the release name. */}}
{{- define "base.cnpg.clusterName" -}}{{ .Release.Name }}-db{{- end -}}
{{- define "base.cnpg.poolerName" -}}{{ .Release.Name }}-pooler-rw{{- end -}}
{{- define "base.cnpg.secretName" -}}{{ .Release.Name }}-db-{{ .Values.cnpg.user.name }}{{- end -}}
{{- define "base.cnpg.poolerHost" -}}{{ .Release.Name }}-pooler-rw.{{ .Release.Namespace }}.svc.cluster.local{{- end -}}
{{- define "base.cnpg.barmanObjectName" -}}{{ .Release.Name }}{{- end -}}

{{/* Volsync naming + flavor-aware class/accessMode resolution. */}}
{{- define "base.volsync.pvcName" -}}{{ .Release.Name }}{{- end -}}
{{- define "base.volsync.dstName" -}}{{ .Release.Name }}-dst{{- end -}}

{{- define "base.volsync.storageClass" -}}
{{- if .Values.volsync.storageClass -}}
{{ .Values.volsync.storageClass }}
{{- else if eq .Values.volsync.flavor "cephfs" -}}
ceph-filesystem
{{- else -}}
ceph-block
{{- end -}}
{{- end -}}

{{- define "base.volsync.snapshotClass" -}}
{{- if .Values.volsync.snapshotClass -}}
{{ .Values.volsync.snapshotClass }}
{{- else if eq .Values.volsync.flavor "cephfs" -}}
csi-ceph-filesystem
{{- else -}}
csi-ceph-blockpool
{{- end -}}
{{- end -}}

{{- define "base.volsync.accessModes" -}}
{{- if .Values.volsync.accessModes -}}
{{ toYaml .Values.volsync.accessModes }}
{{- else if eq .Values.volsync.flavor "cephfs" -}}
- ReadWriteMany
{{- else -}}
- ReadWriteOnce
{{- end -}}
{{- end -}}
