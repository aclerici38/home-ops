{{- define "resources.oidc.backendSpec" -}}
{{- $o := .Values.oidc -}}
type: Static
static:
  hosts:
    - host: {{ dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" $o }}
      port: {{ dig "backendPort" 1411 $o }}
{{- end -}}

{{- define "resources.oidc.backendConfigSpec" -}}
targetRefs:
  - group: gateway.kgateway.dev
    kind: Backend
    name: {{ include "resources.app" . }}-oauth-backend
tls:
  sni: {{ dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" .Values.oidc | quote }}
  wellKnownCACertificates: System
{{- end -}}

{{/* Endpoints are set explicitly and issuerURI deliberately is NOT, so the control
     plane never runs OIDC discovery. Discovery resolves the issuer back through the
     very Gateway kgateway is configuring: start before pocket-id is serving and it
     caches the 503 indefinitely, replacing every route on this policy with a 500
     until the GatewayExtension spec changes. jwksURI is required once discovery is
     off and a token is parsed. */}}
{{- define "resources.oidc.extensionSpec" -}}
{{- $app := include "resources.app" . -}}
{{- $o := .Values.oidc -}}
{{- $issuer := "https://id.clerici.tech" -}}
{{- /* oidc.clientID > pocketId.clientID > app name. */ -}}
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
{{/* cookies.domain is the parent domain, so every app's session cookie is sent
     to every other app on it, under the same default cookie names. Without an
     audience check the only gates left are signature and issuer, which every
     token from this issuer passes — so a session minted for one client would
     authenticate against another, and Pocket-ID's per-client allowedUserGroups
     (enforced at /authorize) would no longer bind. Pinning aud to this client
     is what keeps that restriction meaningful. */}}
  jwt:
    idToken:
      audiences:
        - {{ $clientID | quote }}
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
