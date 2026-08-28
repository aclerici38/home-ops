{{- define "resources.externalSecret.spec" -}}
{{- $app := include "resources.app" . -}}
{{- $es := .Values.externalSecret -}}
refreshInterval: "1m"
secretStoreRef:
  kind: ClusterSecretStore
  name: onepassword-connect
dataFrom:
  {{- /* dataFrom is a list; a merge would replace the entry, not retarget it. */}}
  - extract:
      key: {{ dig "key" $app $es }}
{{- end -}}
