{{/* cephfs:true stages the source snapshot on a backingSnapshot (shallow, read-only)
     class so kopiur mounts it directly — a 25Gi Ceph full clone blew the 10m staging
     timeout. Block/RBD clones are fast CoW, so staging stays empty there. */}}
{{- define "resources.kopiur.storage" -}}
{{- $k := .Values.kopiur -}}
{{- $cephfs := dig "cephfs" false $k -}}
storageClass: {{ dig "storageClass" (ternary "ceph-filesystem" "ceph-block" $cephfs) $k }}
snapshotClass: {{ ternary "csi-ceph-filesystem" "csi-ceph-blockpool" $cephfs }}
accessMode: {{ ternary "ReadWriteMany" "ReadWriteOnce" $cephfs }}
stagingClass: {{ ternary "ceph-filesystem-backingsnapshot" "" $cephfs }}
{{- end -}}

{{- define "resources.kopiur.policySpec" -}}
{{- $app := include "resources.app" . -}}
{{- $k := .Values.kopiur -}}
{{- $st := fromYaml (include "resources.kopiur.storage" .) -}}
{{- $ignoreRules := dig "ignoreRules" list $k -}}
repository:
  kind: ClusterRepository
  name: versity
sources:
  - pvc:
      name: {{ $app }}
copyMethod: Snapshot
volumeSnapshotClassName: {{ $st.snapshotClass }}
{{- with $st.stagingClass }}
staging:
  storageClassName: {{ . }}
  accessModes: [ReadOnlyMany]
{{- end }}
compression:
  compressor: zstd
upload:
  {{- /* raphael overrides to 1 so a backup can't spike its 4-core N100 (heat). */}}
  maxParallelFileReads: 4
files:
  ignoreIdenticalSnapshots: true
  {{- with $ignoreRules }}
  {{- /* An explicit list replaces the operator default, so re-add /lost+found. */}}
  ignoreRules:
    {{- prepend . "/lost+found" | uniq | toYaml | nindent 4 }}
  {{- end }}
retention:
  keepDaily: 7
  keepWeekly: 4
{{- /* Requires credentialProjection.allowed on the repository and
       features.credentialProjection on the operator (both set). */}}
credentialProjection:
  enabled: true
{{- /* Away from the home S3 the Snapshot holds Pending instead of spawning a
       mover Job that crashloops. timeout 0s holds indefinitely; the schedule's
       Forbid concurrency keeps one waiting. Requires health.probe on the repo. */}}
preflight:
  checks:
    - name: backend-reachable
      expr: "repository.backendReachable"
      message: "S3 store unreachable"
  timeout: "0s"
{{- end -}}

{{- define "resources.kopiur.scheduleSpec" -}}
policyRef:
  name: {{ include "resources.app" . }}
schedule:
  cron: "0 3 * * *"
  {{- /* Set explicitly, not left to the controller's UTC default. */}}
  timezone: America/Los_Angeles
  jitter: 30m
  runOnCreate: false
{{- end -}}

{{- define "resources.kopiur.restoreSpec" -}}
{{- $app := include "resources.app" . -}}
source:
  fromPolicy:
    name: {{ $app }}
    namespace: {{ include "resources.ns" . }}
    offset: 0
target:
  populator: {}
policy:
  {{- /* Provision a blank volume on an empty repo rather than failing. */}}
  onMissingSnapshot: Continue
credentialProjection:
  enabled: true
{{- end -}}

{{- define "resources.kopiur.pvcSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $st := fromYaml (include "resources.kopiur.storage" .) -}}
accessModes: [{{ $st.accessMode | quote }}]
dataSourceRef:
  apiGroup: kopiur.home-operations.com
  kind: Restore
  name: {{ $app }}
resources:
  requests:
    storage: {{ dig "capacity" "5Gi" .Values.kopiur | quote }}
storageClassName: {{ $st.storageClass }}
{{- end -}}
