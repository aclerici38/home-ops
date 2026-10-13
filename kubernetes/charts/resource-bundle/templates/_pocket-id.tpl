{{- define "resources.pocketId.spec" -}}
{{- $app := include "resources.app" . -}}
{{- $p := .Values.pocketId -}}
{{- $clientID := dig "clientID" $app $p -}}
{{- $name := dig "name" $clientID $p -}}
{{- $host := dig "url" (printf "%s.clerici.tech" $app) $p -}}
{{- $cbs := dig "callbackUrls" list $p -}}
{{- range dig "callbackPaths" list $p }}{{ $cbs = append $cbs (printf "https://%s%s" $host .) }}{{- end -}}
{{- $lcbs := dig "logoutCallbackUrls" list $p -}}
{{- range dig "logoutCallbackPaths" list $p }}{{ $lcbs = append $lcbs (printf "https://%s%s" $host .) }}{{- end -}}
{{- /* Envoy Gateway's oauth2 filter sends post_logout_redirect_uri=https://<host>/ when a
       browser hits its logoutPath, and pocket-id drops a return address it wasn't
       told about, stranding the user on the pocket-id logout page. */ -}}
{{- if and (hasKey .Values "oidc") (not $lcbs) }}{{ $lcbs = list (printf "https://%s/" $host) }}{{- end -}}
name: {{ $name | quote }}
logo:
  nameOverride: {{ $name }}
clientID: {{ $clientID }}
launchUrl: https://{{ $host }}
pkceEnabled: true
skipConsent: {{ dig "skipConsent" true $p }}
{{- /* A public client has no secret; the CRD rejects clientSecretOverlap on one. */}}
{{- if not (dig "spec" "oidcClient" "isPublic" false $p) }}
clientSecretRotation:
  enabled: true
  interval: 6h
  window:
    opens: "0 0 * * *"
    closesAfter: 4h
clientSecretOverlap: 15m
{{- end }}
{{- /* A group managed outside this cluster overrides spec.oidcClient.allowedUserGroups
       instead ([{groupName: admin}] / [{groupID: <id>}]). */}}
allowedUserGroups:
  - name: {{ dig "group" "admin" $p }}
    namespace: pocket-id-operator
{{- with $cbs }}
callbackUrls: {{ toYaml . | nindent 2 }}
{{- end }}
{{- with $lcbs }}
logoutCallbackUrls: {{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- /* Allow-only, like <app>-postgres: the app's own policy decides enforcement.
       In-cluster, id.clerici.tech resolves to the external gateway's LB IP, which
       Cilium translates before policy, so it's matched as the Envoy pod. */}}
{{- define "resources.pocketId.networkPolicySpec" -}}
{{- $p := .Values.pocketId -}}
endpointSelector:
  matchLabels:
    {{- toYaml (dig "podLabels" (dict "app.kubernetes.io/instance" (include "resources.app" .)) $p) | nindent 4 }}
enableDefaultDeny:
  ingress: false
  egress: false
egress:
{{- if dig "external" false $p }}
  - toFQDNs:
      - matchName: id.clerici.tech
    toPorts:
      - ports:
          - {port: "443", protocol: TCP}
{{- else }}
  - toEndpoints:
      - matchLabels:
          k8s:io.kubernetes.pod.namespace: envoy-gateway
          gateway.envoyproxy.io/owning-gateway-name: external
    toPorts:
      - ports:
          - {port: "10443", protocol: TCP}
{{- end }}
{{- end -}}
