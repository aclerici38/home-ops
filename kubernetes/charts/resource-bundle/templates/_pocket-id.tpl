{{- define "resources.pocketId.spec" -}}
{{- $app := include "resources.app" . -}}
{{- $p := .Values.pocketId -}}
{{- /* Feeds spec.clientID, the display-name default, and oidc.yaml's credentials
       — three places across two templates, so it stays a knob. */ -}}
{{- $clientID := dig "clientID" $app $p -}}
{{- /* Display name in the pocket-id UI; also the logo nameOverride default. */ -}}
{{- $name := dig "name" $clientID $p -}}
{{- /* Feeds launchUrl and every callbackPaths entry below. */ -}}
{{- $host := dig "url" (printf "%s.clerici.tech" $app) $p -}}
{{- /* callbackUrls = literal entries + https://<host><path> per callbackPaths
       entry. A computed list, not a mergeable field, so both stay knobs. */ -}}
{{- $cbs := dig "callbackUrls" list $p -}}
{{- range dig "callbackPaths" list $p }}{{ $cbs = append $cbs (printf "https://%s%s" $host .) }}{{- end -}}
name: {{ $name | quote }}
logo:
  nameOverride: {{ $name }}
clientID: {{ $clientID }}
launchUrl: https://{{ $host }}
pkceEnabled: true
clientSecretRotation:
  enabled: true
  interval: 6h
  window:
    opens: "0 0 * * *"
    closesAfter: 4h
{{- /* The PocketIDUserGroup CR of that name in the operator namespace. A group
       managed outside this cluster overrides spec.allowedUserGroups instead
       ([{groupName: admin}] / [{groupID: <id>}]) — the merge replaces this list
       wholesale, which is what you want there. */}}
allowedUserGroups:
  - name: {{ dig "group" "admin" $p }}
    namespace: pocket-id-operator
{{- with $cbs }}
callbackUrls: {{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
