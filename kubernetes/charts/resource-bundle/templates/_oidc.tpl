{{/* kgateway oauth2 forward-auth for an HTTPRoute, backed by pocket-id. */}}

{{- define "resources.oidc.backendSpec" -}}
{{- $o := .Values.oidc -}}
type: Static
static:
  hosts:
    - host: {{ dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" $o }}
      port: {{ dig "backendPort" 1411 $o }}
{{- end -}}

{{- define "resources.oidc.backendConfigSpec" -}}
{{- $app := include "resources.app" . -}}
targetRefs:
  - group: gateway.kgateway.dev
    kind: Backend
    name: {{ $app }}-oauth-backend
tls:
  sni: {{ dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" .Values.oidc | quote }}
  wellKnownCACertificates: System
{{- end -}}

{{/* Every endpoint below is set explicitly and issuerURI is deliberately NOT set,
     so the control plane never runs OIDC discovery. Discovery resolves the issuer
     back through the very Gateway kgateway is configuring: if the control plane
     starts before pocket-id is serving it gets a 503, caches that failure
     indefinitely, and replaces every route carrying this policy with a 500 direct
     response until the GatewayExtension spec changes. Paths are pocket-id's;
     jwksURI is required once discovery is off and a token is parsed. */}}
{{- define "resources.oidc.extensionSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $o := .Values.oidc -}}
{{- /* Shared by the four endpoints here and the csrf origin in the TrafficPolicy.
       A chart constant rather than a knob: override the endpoints themselves via
       extensionSpec if you ever point an app at a different IdP. */ -}}
{{- $issuer := "https://id.clerici.tech" -}}
{{- /* clientID precedence: oidc.clientID > pocketId.clientID > app name. */ -}}
{{- $clientID := dig "clientID" (dig "clientID" $app (.Values.pocketId | default dict)) $o -}}
oauth2:
  backendRef:
    group: gateway.kgateway.dev
    kind: Backend
    name: {{ $app }}-oauth-backend
  authorizationEndpoint: {{ printf "%s/authorize" $issuer | quote }}
  tokenEndpoint: {{ printf "%s/api/oidc/token" $issuer | quote }}
  endSessionEndpoint: {{ printf "%s/api/oidc/end-session" $issuer | quote }}
  scopes:
    - openid
    - profile
    - email
    - groups
  credentials:
    clientID: {{ $clientID | quote }}
    clientSecretRef:
      name: {{ $app }}-oidc-credentials
  cookies:
    domain: "clerici.tech"
  jwt:
    jwksURI: {{ printf "%s/.well-known/jwks.json" $issuer | quote }}
{{- end -}}

{{- define "resources.oidc.trafficPolicySpec" -}}
{{- $app := include "resources.app" . -}}
targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: {{ dig "route" $app .Values.oidc }}
csrf:
  percentageEnabled: 100
  additionalOrigins:
    - exact: "https://id.clerici.tech"
oauth2:
  extensionRef:
    name: {{ $app }}-oauth
{{- end -}}
