{{- define "resources.pocketId.spec" -}}
{{- $app := include "resources.app" . -}}
{{- $p := .Values.pocketId -}}
{{- $clientID := dig "clientID" $app $p -}}
{{- $name := dig "name" $clientID $p -}}
{{- $host := dig "url" (printf "%s.clerici.tech" $app) $p -}}
{{- $cbs := dig "callbackUrls" list $p -}}
{{- range dig "callbackPaths" list $p }}{{ $cbs = append $cbs (printf "https://%s%s" $host .) }}{{- end -}}
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
{{- end -}}
