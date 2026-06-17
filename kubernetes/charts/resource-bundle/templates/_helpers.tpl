{{/* App name: explicit override, else release name minus a trailing "-resources". */}}
{{- define "resources.app" -}}
{{- default (.Release.Name | trimSuffix "-resources") .Values.app -}}
{{- end -}}

{{- define "resources.ns" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{/* The CNPG Cluster .spec as YAML, before the clusterSpec escape-hatch merge. */}}
{{- define "resources.cnpg.clusterSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $c := .Values.cnpg -}}
{{- $instances := int (dig "instances" 3 $c) -}}
{{- $single := eq $instances 1 -}}
affinity:
  {{- /* A single-instance cluster has nothing to anti-affine; "preferred" keeps
         the pod schedulable on a single-node cluster (and during its own
         restart) instead of being blocked by a "required" rule. */}}
  podAntiAffinityType: {{ ternary "preferred" "required" $single }}
  nodeSelector:
    storage.openebs.io/hostpath: "true"
instances: {{ $instances }}
primaryUpdateStrategy: unsupervised
{{- /* With one instance there is no replica to promote, so updates restart the
       primary in place; multi-instance clusters switch over first. */}}
primaryUpdateMethod: {{ ternary "restart" "switchover" $single }}
{{- /* A PDB on a single-instance cluster only blocks node drains (there is no
       second pod to keep available), so disable it. */}}
enablePDB: {{ not $single }}
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ClusterImageCatalog
  major: 18
  name: postgresql-minimal-trixie
storage:
  size: {{ dig "capacity" "2Gi" $c }}
  storageClass: openebs-hostpath
superuserSecret:
  name: cloudnative-pg
enableSuperuserAccess: true
postgresql:
  {{- /* Synchronous replication needs at least one standby; a single-instance
         cluster has none, so the durability guarantee is the primary's PVC. */}}
  {{- if not $single }}
  synchronous:
    method: any
    number: 1
    dataDurability: preferred
    failoverQuorum: true
  {{- end }}
  {{- with $c.pgExtensions }}
  {{- $exts := list }}
  {{- range . }}
  {{- $exts = append $exts (ternary (dict "name" .) . (kindIs "string" .)) }}
  {{- end }}
  extensions: {{ toYaml $exts | nindent 4 }}
  {{- end }}
  {{- with $c.preload }}
  shared_preload_libraries: {{ toYaml . | nindent 4 }}
  {{- end }}
  parameters:
    shared_buffers: 512MB
    work_mem: 8MB
    maintenance_work_mem: 128MB
    effective_cache_size: 1536MB
    wal_buffers: 16MB
    checkpoint_timeout: 10min
    max_wal_size: 4GB
    min_wal_size: 1GB
    max_slot_wal_keep_size: 10GB
    checkpoint_completion_target: "0.9"
    wal_keep_size: 4GB
    wal_sender_timeout: 60s
    wal_receiver_timeout: 60s
    log_min_duration_statement: "500"
    log_checkpoints: "on"
    log_autovacuum_min_duration: "250"
    log_temp_files: 128MB
    log_lock_waits: "on"
    autovacuum_vacuum_cost_limit: "2000"
    autovacuum_max_workers: "3"
    autovacuum_naptime: 20s
{{- if ne $c.mode "no-backup" }}
plugins:
  - name: barman-cloud.cloudnative-pg.io
    enabled: true
    isWALArchiver: true
    parameters:
      barmanObjectName: {{ $app }}
      serverName: {{ $app }}-db
{{- end }}
{{- if eq $c.mode "restore" }}
bootstrap:
  recovery:
    source: {{ $app }}-db
externalClusters:
  - name: {{ $app }}-db
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: {{ $app }}
        serverName: {{ $app }}-db
{{- end }}
{{- end -}}
