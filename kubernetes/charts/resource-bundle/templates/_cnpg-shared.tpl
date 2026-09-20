{{/* Shared-cluster identity — each feeds two or more documents. */}}
{{- define "resources.cnpgShared.ident" -}}
{{- $app := include "resources.app" . -}}
{{- $c := .Values.cnpg -}}
{{- $cnpgNs := dig "clusterNamespace" "cloudnative-pg" $c -}}
{{- $session := eq (dig "poolMode" "transaction" $c) "session" -}}
{{- $mtls := dig "mtls" false $c -}}
{{- $cluster := dig "cluster" "pg18" $c -}}
{{- /* Session-scoped apps use a session pooler, everyone else transaction;
       mTLS apps the cert-only pair (pg18-pooler-mtls-*). */}}
{{- $pooler := printf "pg18-pooler%s%s-rw" ($mtls | ternary "-mtls" "") ($session | ternary "-session" "") }}
mtls: {{ $mtls }}
readOnly: {{ dig "readOnly" false $c }}
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
{{- $in := list }}
{{- /* Cert-only: no password at all; cert_apps is what the mTLS poolers may act for. */}}
{{- if $i.mtls }}{{ $in = append $in "cert_apps" }}{{ end }}
{{- /* Readers: SELECT everywhere, fenced to one database by pg_hba. */}}
{{- if $i.readOnly }}{{ $in = append $in "pg_read_all_data" }}{{ end }}
{{- if $i.mtls }}
disablePassword: true
{{- else }}
passwordSecret:
  name: {{ include "resources.app" . }}-role
{{- end }}
{{- with $in }}
inRoles:
  {{- toYaml . | nindent 2 }}
{{- end }}
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
      # Verified TLS by default; point the client at ca.crt (e.g. NODE_EXTRA_CA_CERTS / sslrootcert).
      uri: {{ printf "postgresql://%s:%s@%s:5432/%s?sslmode=verify-full" $role $pw $host $db | quote }}
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


{{- /* Where apps mount the client cert Secret (tls.crt, tls.key, ca.crt). */}}
{{- define "resources.cnpgShared.certDir" -}}/var/run/secrets/postgresql{{- end -}}

{{- /* Name of the client cert Certificate and the Secret it writes. */}}
{{- define "resources.cnpgShared.certName" -}}{{ include "resources.app" . }}-postgres-cert{{- end -}}

{{/* Client cert for the cert-only pooler, CN = the role the pooler acts for.
     Renewal rewrites the Secret, which reloader watches, so the app is rolled:
     many drivers read sslcert/sslkey once and pin the PEM for the life of the
     process, and would otherwise keep presenting the expired cert. */}}
{{- define "resources.cnpgShared.certificateSpec" -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
secretName: {{ include "resources.cnpgShared.certName" . }}
commonName: {{ $i.role }}
usages:
  - client auth
  - digital signature
duration: 720h
renewBefore: 240h
privateKey:
  algorithm: ECDSA
  size: 384
  encoding: PKCS8
  rotationPolicy: Always
issuerRef:
  group: cert-manager.io
  kind: ClusterIssuer
  name: postgres-mtls
{{- end -}}

{{- /* mTLS connection settings: nothing secret, so a ConfigMap. */}}
{{- define "resources.cnpgShared.mtlsConfigData" -}}
{{- $i := fromYaml (include "resources.cnpgShared.ident" .) -}}
{{- $dir := include "resources.cnpgShared.certDir" . -}}
{{- $tls := printf "sslmode=verify-full&sslcert=%s/tls.crt&sslkey=%s/tls.key&sslrootcert=%s/ca.crt" $dir $dir $dir -}}
user: {{ $i.role }}
username: {{ $i.role }}
dbname: {{ $i.database }}
host: {{ $i.host | quote }}
port: "5432"
sslmode: verify-full
sslcert: {{ $dir }}/tls.crt
sslkey: {{ $dir }}/tls.key
sslrootcert: {{ $dir }}/ca.crt
uri: {{ printf "postgresql://%s@%s:5432/%s?%s" $i.role $i.host $i.database $tls | quote }}
{{- /* Npgsql (.NET) connection-string form of the same settings. */}}
npgsql: {{ printf "Host=%s;Port=5432;Database=%s;Username=%s;SSL Mode=VerifyFull;Root Certificate=%s/ca.crt;SSL Certificate=%s/tls.crt;SSL Key=%s/tls.key" $i.host $i.database $i.role $dir $dir $dir | quote }}
{{- end -}}
