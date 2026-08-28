{{- define "resources.cnpg.clusterSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $c := .Values.cnpg -}}
{{- /* One instance flips four correlated fields, so it stays a knob: nothing to
       anti-affine, no replica to promote, no second pod for a PDB to protect,
       and no standby for synchronous replication (durability is the primary's
       PVC). "preferred" also keeps the pod schedulable on a single-node cluster
       and during its own restart. */ -}}
{{- $single := eq (int (dig "instances" 3 $c)) 1 -}}
{{- $backup := ne $c.mode "no-backup" -}}
affinity:
  podAntiAffinityType: {{ ternary "preferred" "required" $single }}
  nodeSelector:
    storage.openebs.io/hostpath: "true"
instances: {{ dig "instances" 3 $c }}
primaryUpdateStrategy: unsupervised
primaryUpdateMethod: {{ ternary "restart" "switchover" $single }}
enablePDB: {{ not $single }}
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ClusterImageCatalog
  major: 18
  name: postgresql-minimal-trixie
storage:
  size: 2Gi
  storageClass: openebs-hostpath
superuserSecret:
  name: cloudnative-pg
enableSuperuserAccess: true
postgresql:
  {{- if not $single }}
  synchronous:
    method: any
    number: 1
    dataDurability: preferred
    failoverQuorum: true
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
{{- if $backup }}
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

{{- define "resources.cnpg.poolerSpec" -}}
{{- $app := include "resources.app" . -}}
cluster:
  name: {{ $app }}-db
instances: 1
type: rw
pgbouncer:
  {{- /* Also selects the shared-cluster pooler service in cnpg-shared.yaml, so
         one knob spans both modes. */}}
  poolMode: {{ dig "poolMode" "transaction" .Values.cnpg | quote }}
  parameters:
    default_pool_size: "30"
    min_pool_size: "5"
    reserve_pool_size: "10"
    reserve_pool_timeout: "5"
    max_client_conn: "500"
    listen_backlog: "1024"
    query_wait_timeout: "120"
    idle_transaction_timeout: "60"
    server_idle_timeout: "180"
    max_prepared_statements: "200"
{{- end -}}

{{- define "resources.cnpg.databaseSpec" -}}
{{- $app := include "resources.app" . -}}
name: app
owner: app
cluster:
  name: {{ $app }}-db
{{- end -}}

{{- define "resources.cnpg.objectStoreSpec" -}}
retentionPolicy: 14d
configuration:
  data: {compression: gzip, jobs: 8}
  wal: {compression: zstd, maxParallel: 12}
  destinationPath: s3://cnpg
  endpointURL: http://versitygw.versity.svc.cluster.local:7070
  historyTags: {keepHistory: "true"}
  s3Credentials:
    accessKeyId: {name: cloudnative-pg, key: versity-access-key-id}
    secretAccessKey: {name: cloudnative-pg, key: versity-secret-access-key}
{{- end -}}

{{- define "resources.cnpg.scheduledBackupSpec" -}}
{{- $app := include "resources.app" . -}}
schedule: "0 0 4 * * *"
immediate: true
backupOwnerReference: self
cluster:
  name: {{ $app }}-db
method: plugin
pluginConfiguration:
  name: barman-cloud.cloudnative-pg.io
{{- end -}}

{{/* App connection secret. Fully derived from the app name and pooler host —
     closed, so it has no merge key. */}}
{{- define "resources.cnpg.appSecretSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $host := printf "%s-pooler-rw.%s.svc.cluster.local" $app (include "resources.ns" .) -}}
{{- $pw := "{{ .password }}" -}}
refreshPolicy: OnChange
target:
  creationPolicy: Orphan
  template:
    engineVersion: v2
    metadata:
      labels:
        cnpg.io/cluster: {{ $app }}-db
        cnpg.io/userType: app
        cnpg.io/reload: "true"
    data:
      user: app
      username: app
      dbname: app
      host: {{ $host | quote }}
      password: {{ $pw | quote }}
      port: "5432"
      pgpass: {{ printf "%s:5432:app:app:%s" $host $pw | quote }}
      jdbc-uri: {{ printf "jdbc:postgresql://%s:5432/app?password=%s&user=app" $host $pw | quote }}
      uri: {{ printf "postgresql://app:%s@%s:5432/app" $pw $host | quote }}
dataFrom:
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: ClusterGenerator
        name: cnpg-pass-generator
{{- end -}}
