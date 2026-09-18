{{/* Shared-cluster identity — each feeds two or more documents. */}}
{{- define "resources.cnpgShared.ident" -}}
{{- $app := include "resources.app" . -}}
{{- $c := .Values.cnpg -}}
{{- $cnpgNs := dig "clusterNamespace" "cloudnative-pg" $c -}}
{{- $session := eq (dig "poolMode" "transaction" $c) "session" -}}
{{- $cluster := dig "cluster" "pg18" $c -}}
{{- /* Session-scoped apps use the session pooler, everyone else transaction. */}}
{{- $pooler := $session | ternary "pg18-pooler-session-rw" "pg18-pooler-rw" }}
cluster: {{ $cluster }}
namespace: {{ $cnpgNs }}
database: {{ dig "database" $app $c }}
role: {{ $app }}
pooler: {{ $pooler }}
host: {{ printf "%s.%s.svc.cluster.local" $pooler $cnpgNs }}
{{- end -}}

{{- define "resources.cnpgShared.roleSpec" -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
cluster:
  name: {{ $i.cluster }}
name: {{ $i.role }}
ensure: present
login: true
databaseRoleReclaimPolicy: retain
passwordSecret:
  name: {{ include "resources.app" . }}-role
{{- end -}}

{{- define "resources.cnpgShared.databaseSpec" -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
name: {{ $i.database }}
owner: {{ $i.role }}
cluster:
  name: {{ $i.cluster }}
databaseReclaimPolicy: retain
{{- end -}}

{{- define "resources.cnpgShared.roleSecretSpec" -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
{{- $pw := "{{ .password }}" -}}
refreshPolicy: OnChange
target:
  creationPolicy: Orphan
  template:
    engineVersion: v2
    type: kubernetes.io/basic-auth
    metadata:
      labels:
        cnpg.io/reload: "true"
    data:
      username: {{ $i.role }}
      password: {{ $pw | quote }}
dataFrom:
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: ClusterGenerator
        name: cnpg-pass-generator
{{- end -}}

{{- define "resources.cnpgShared.appSecretSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
{{- $pw := "{{ .password }}" -}}
{{- $ca := "{{ index . \"ca.crt\" }}" -}}
{{- $host := $i.host -}}{{- $db := $i.database -}}{{- $role := $i.role -}}
refreshInterval: "1h"
secretStoreRef:
  kind: ClusterSecretStore
  name: cnpg-role-secrets
target:
  # Owner (not Orphan): a reproducible mirror, so let ESO recreate it if deleted.
  creationPolicy: Owner
  template:
    engineVersion: v2
    metadata:
      labels:
        cnpg.io/reload: "true"
    data:
      user: {{ $role }}
      username: {{ $role }}
      dbname: {{ $db }}
      host: {{ $host | quote }}
      password: {{ $pw | quote }}
      port: "5432"
      # Cluster CA (the poolers serve the cluster's server cert) for sslmode=verify-full.
      ca.crt: {{ $ca | quote }}
      pgpass: {{ printf "%s:5432:%s:%s:%s" $host $db $role $pw | quote }}
      jdbc-uri: {{ printf "jdbc:postgresql://%s:5432/%s?password=%s&user=%s" $host $db $pw $role | quote }}
      uri: {{ printf "postgresql://%s:%s@%s:5432/%s" $role $pw $host $db | quote }}
data:
  - secretKey: password
    remoteRef:
      key: {{ $app }}-role
      property: password
  - secretKey: ca.crt
    remoteRef:
      key: {{ $i.cluster }}-ca
      property: ca.crt
{{- end -}}
