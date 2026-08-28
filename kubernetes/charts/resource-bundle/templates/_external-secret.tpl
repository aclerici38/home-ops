{{- define "resources.externalSecret.spec" -}}
{{- $app := include "resources.app" . -}}
{{- $es := .Values.externalSecret -}}
refreshInterval: "1m"
secretStoreRef:
  kind: ClusterSecretStore
  name: onepassword-connect
dataFrom:
  {{- /* 1Password item to extract. Stays a knob because dataFrom is a list and
         a merge would replace the entry wholesale rather than retarget it. */}}
  - extract:
      key: {{ dig "key" $app $es }}
{{- end -}}
