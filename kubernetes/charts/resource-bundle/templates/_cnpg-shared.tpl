{{/* Shared-cluster identity. Each of these feeds two or more documents (or the
     connection strings), which is why they stay knobs rather than merge fields. */}}
{{- define "resources.cnpgShared.ident" -}}
{{- $app := include "resources.app" . -}}
{{- $c := .Values.cnpg -}}
{{- $cnpgNs := dig "clusterNamespace" "cloudnative-pg" $c -}}
{{- $session := eq (dig "poolMode" "transaction" $c) "session" -}}
cluster: {{ dig "cluster" "pg18" $c }}
namespace: {{ $cnpgNs }}
database: {{ dig "database" $app $c }}
role: {{ $app }}
{{- /* Session-scoped apps go through the session-mode pooler; everyone else
       through the transaction pooler. */}}
host: {{ $session | ternary (printf "pg18-pooler-session-rw.%s.svc.cluster.local" $cnpgNs) (printf "pg18-pooler-rw.%s.svc.cluster.local" $cnpgNs) }}
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
{{- $host := $i.host -}}{{- $db := $i.database -}}{{- $role := $i.role -}}
refreshInterval: "1h"
secretStoreRef:
  kind: ClusterSecretStore
  name: cnpg-role-secrets
target:
  # Owner (not Orphan): this secret is a reproducible mirror of the <app>-role
  # password, so let ESO own + watch it and recreate it immediately if it's
  # ever deleted (e.g. the legacy secret being cascade-removed during the flip).
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
      pgpass: {{ printf "%s:5432:%s:%s:%s" $host $db $role $pw | quote }}
      jdbc-uri: {{ printf "jdbc:postgresql://%s:5432/%s?password=%s&user=%s" $host $db $pw $role | quote }}
      uri: {{ printf "postgresql://%s:%s@%s:5432/%s" $role $pw $host $db | quote }}
data:
  - secretKey: password
    remoteRef:
      key: {{ $app }}-role
      property: password
{{- end -}}
