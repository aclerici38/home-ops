{{/* Endpoints are explicit so discovery never runs: it would resolve the issuer
     back through the very Gateway this policy guards, and a cold start would
     leave the policy unprogrammed.

     An HTTPRoute accepts only one SecurityPolicy, so csrf lives here too. */}}
{{- define "resources.oidc.securityPolicySpec" -}}
{{- $app := include "resources.app" . -}}
{{- $o := .Values.oidc -}}
{{- $issuerHost := "id.clerici.tech" -}}
{{- $issuer := printf "https://%s" $issuerHost -}}
{{- /* oidc.clientID > pocketId.clientID > app name. */ -}}
{{- $clientID := dig "clientID" (dig "clientID" $app (.Values.pocketId | default dict)) $o -}}
targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: {{ dig "route" $app $o }}
oidc:
  provider:
    issuer: {{ $issuer | quote }}
    authorizationEndpoint: {{ printf "%s/authorize" $issuer | quote }}
    tokenEndpoint: {{ printf "%s/api/oidc/token" $issuer | quote }}
    endSessionEndpoint: {{ printf "%s/api/oidc/end-session" $issuer | quote }}
{{- if ne (dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" $o) $issuerHost }}
    {{- /* Only when short-circuiting the issuer host. Left unset, Envoy Gateway
           builds a STRICT_DNS cluster from the token endpoint itself and
           originates TLS with the system trust bundle. */}}
    backendRefs:
      - group: gateway.envoyproxy.io
        kind: Backend
        name: {{ $app }}-oidc-backend
{{- end }}
  clientID: {{ $clientID | quote }}
  {{- /* Envoy Gateway reads the fixed key "client-secret"; there is no key field. */}}
  clientSecret:
    name: {{ $app }}-oidc-credentials
  scopes:
    - profile
    - email
    - groups
  {{- /* Parent domain: one session across every app. Safe because the ID token
         is validated against this policy's own clientID, so pocket-id's
         per-client allowedUserGroups still binds. */}}
  cookieDomain: "clerici.tech"
  refreshToken: true
csrf:
  additionalOrigins:
    - "https://id.clerici.tech"
{{- end -}}

{{- define "resources.oidc.needsBackend" -}}
{{- $o := .Values.oidc -}}
{{- if ne (dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" $o) "id.clerici.tech" }}true{{ end }}
{{- end -}}

{{- define "resources.oidc.backendSpec" -}}
{{- $o := .Values.oidc -}}
{{- $host := dig "backendHost" "pocket-id.pocket-id-operator.svc.cluster.local" $o -}}
{{- $port := dig "backendPort" 1411 $o -}}
endpoints:
  - fqdn:
      hostname: {{ $host | quote }}
      port: {{ $port }}
{{- /* Originate TLS to a remote pocket-id (id.clerici.tech:443). */}}
{{- if dig "backendTLS" (eq (toString $port) "443") $o }}
tls:
  sni: {{ $host | quote }}
  wellKnownCACertificates: System
{{- end }}
{{- end -}}
