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
clientSecretRotation:
  enabled: true
  interval: 6h
  window:
    opens: "0 0 * * *"
    closesAfter: 4h
clientSecretOverlap: 15m
{{- /* A group managed outside this cluster overrides spec.allowedUserGroups
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
