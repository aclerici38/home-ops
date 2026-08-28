{{/* cephfs-derived storage identities. One input, four correlated fields —
     the reason this stays code instead of collapsing into the spec merge.
     cephfs:true flips the volume to RWX CephFS and stages the backup's source
     snapshot on a backingSnapshot (shallow, read-only) class so kopiur mounts
     the snapshot directly instead of Ceph doing a slow full clone — a 25Gi
     clone blew past the 10m staging timeout. Block/RBD clones are fast CoW, so
     staging stays empty there (kopiur uses the data SC). Defaults are home's
     Ceph; raphael overrides storageClass to "miroir" per app. */}}
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
{{- /* Path globs kopia skips — keeps churny, rebuildable state out of the repo.
       Stays a named knob because an explicit list REPLACES the operator default
       wholesale and a spec merge would silently drop the /lost+found prepend
       below. Every app on this chart is on an ext4 volume. */ -}}
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
  # Read-only shallow mount (no full clone). Only the mover reads it, so
  # ReadOnlyMany is enough and staging binds near-instantly.
  storageClassName: {{ . }}
  accessModes: [ReadOnlyMany]
{{- end }}
compression:
  compressor: zstd
upload:
  # kopia --max-parallel-file-reads. 4 suits home's nodes; raphael overrides to
  # 1 via spec.upload so a backup can't spike its 4-core N100 (heat).
  maxParallelFileReads: 4
files:
  ignoreIdenticalSnapshots: true
  {{- with $ignoreRules }}
  ignoreRules:
    {{- prepend . "/lost+found" | uniq | toYaml | nindent 4 }}
  {{- end }}
retention:
  keepDaily: 7
  keepWeekly: 4
# The shared repo lives in the kopiur namespace; project its creds into this
# mover's namespace. Requires credentialProjection.allowed on the repository
# and features.credentialProjection on the operator (both set).
credentialProjection:
  enabled: true
# Gate each scheduled backup on backend reachability: when the RV is away from
# the home S3 the Snapshot holds Pending (PreflightFailed) instead of spawning a
# mover Job that crashloops. timeout "0s" holds indefinitely and the schedule's
# default Forbid concurrency keeps exactly one waiting, so it runs as soon as
# you're home. Requires health.probe on the repository.
preflight:
  checks:
    - name: backend-reachable
      expr: "repository.backendReachable"
      message: "S3 store unreachable"
  timeout: "0s"
{{- end -}}

{{- define "resources.kopiur.scheduleSpec" -}}
{{- $app := include "resources.app" . -}}
policyRef:
  name: {{ $app }}
schedule:
  # Daily by default (write-minimised: each run is a Snapshot CR + mover Job +
  # VolumeSnapshot). timezone is set here, not left to the controller's UTC
  # default, so "0 3" means 3am local across every app.
  cron: "0 3 * * *"
  timezone: America/Los_Angeles
  jitter: 30m
  runOnCreate: false
{{- end -}}

{{- define "resources.kopiur.restoreSpec" -}}
{{- $app := include "resources.app" . -}}
source:
  fromPolicy:
    # Defaults to this app's own policy@namespace. For a one-time cross-namespace
    # seed, override source.fromPolicy.namespace via restoreSpec, then drop it
    # once the PVC is populated.
    name: {{ $app }}
    namespace: {{ include "resources.ns" . }}
    offset: 0
target:
  populator: {}
policy:
  onMissingSnapshot: Continue
credentialProjection:
  enabled: true
{{- end -}}

{{- define "resources.kopiur.pvcSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $k := .Values.kopiur -}}
{{- $st := fromYaml (include "resources.kopiur.storage" .) -}}
accessModes: [{{ $st.accessMode | quote }}]
dataSourceRef:
  apiGroup: kopiur.home-operations.com
  kind: Restore
  name: {{ $app }}
resources:
  requests:
    storage: {{ dig "capacity" "5Gi" $k | quote }}
storageClassName: {{ $st.storageClass }}
{{- end -}}
