{{/* pocket-id mints a machine token via client_credentials and ESO parks the
     response in a Secret. The {{ }} below are ESO's own templates, held back
     from Helm with backticks; the ones supplied through .data come straight
     from values and are never touched by Helm, so they need no escaping.

     The PocketIDOIDCClient itself stays hand-written beside the app (see each
     app's *-client.yaml). Its permissions are the security boundary and are
     worth reading literally, and it must be named <app>-<key> so the
     -oidc-credentials Secret the operator writes lines up with the webhook. */}}

{{- define "resources.machineToken.webhookSpec" -}}
url: http://pocket-id.pocket-id-operator.svc.cluster.local:1411/api/oidc/token
method: POST
headers:
  Content-Type: application/x-www-form-urlencoded
  Authorization: Basic {{ `{{ print .creds.client_id ":" .creds.client_secret | b64enc }}` }}
{{- /* resource and scopes come off the client's apiAccess, so one body fits every token. */}}
body: grant_type=client_credentials&resource={{ `{{ urlquery .creds.resource }}` }}&scope={{ `{{ urlquery .creds.scopes }}` }}
{{- /* The whole token response; access_token is the field .data templates read. */}}
result:
  jsonPath: "$"
secrets:
  - name: creds
    {{- /* No key: the entire Secret is exposed to the templates above. ESO refuses
           to read it without an external-secrets.io/type: webhook label, which the
           client's spec.secret.additionalLabels has to supply. */}}
    secretRef:
      name: {{ .name }}-oidc-credentials
{{- end -}}

{{- define "resources.machineToken.externalSecretSpec" -}}
{{- /* Weekly. The token outlives this by far (accessTokenDurationMinutes on the
       client); the refresh only decides how early a fresh one is on hand. */ -}}
refreshInterval: {{ dig "refreshInterval" "168h" .cfg }}
target:
  template:
    engineVersion: v2
    data:
      {{- dig "data" (dict "ACCESS_TOKEN" "{{ .access_token }}") .cfg | toYaml | nindent 6 }}
dataFrom:
  {{- /* dataFrom is a list; a merge would replace the entry, not retarget it. */}}
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: Webhook
        name: {{ .name }}-token
{{- end -}}
