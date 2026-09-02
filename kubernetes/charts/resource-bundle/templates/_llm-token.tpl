{{/* pocket-id mints a machine token via client_credentials and ESO parks the
     response in a Secret. The {{ }} below are ESO's own templates, held back
     from Helm with backticks. */}}

{{/* The PocketIDOIDCClient granting LLM API access, and everything named off it. */}}
{{- define "resources.llmToken.client" -}}
{{- printf "%s-llm" (include "resources.app" .) -}}
{{- end -}}

{{- define "resources.llmToken.webhookSpec" -}}
url: http://pocket-id.pocket-id-operator.svc.cluster.local:1411/api/oidc/token
method: POST
headers:
  Content-Type: application/x-www-form-urlencoded
  Authorization: Basic {{ `{{ print .creds.client_id ":" .creds.client_secret | b64enc }}` }}
body: grant_type=client_credentials&resource={{ `{{ urlquery .creds.resource }}` }}&scope={{ `{{ urlquery .creds.scopes }}` }}
{{- /* The whole token response; access_token is the field the ExternalSecret keeps. */}}
result:
  jsonPath: "$"
secrets:
  - name: creds
    {{- /* No key: the entire Secret is exposed to the templates above. ESO refuses
           to read it without an external-secrets.io/type: webhook label, which the
           client's spec.secret.additionalLabels has to supply. */}}
    secretRef:
      name: {{ include "resources.llmToken.client" . }}-oidc-credentials
{{- end -}}

{{- define "resources.llmToken.externalSecretSpec" -}}
{{- /* Weekly. The token outlives this by far (accessTokenDurationMinutes on the
       client); the refresh only decides how early a fresh one is on hand. */ -}}
refreshInterval: 168h
target:
  template:
    data:
      LLM_GATEWAY_TOKEN: {{ `{{ .access_token }}` | quote }}
dataFrom:
  {{- /* dataFrom is a list; a merge would replace the entry, not retarget it. */}}
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: Webhook
        name: {{ include "resources.llmToken.client" . }}-token
{{- end -}}
