{{/* Release name minus a trailing "-resources", unless .Values.app overrides. */}}
{{- define "resources.app" -}}
{{- default (.Release.Name | trimSuffix "-resources") .Values.app -}}
{{- end -}}

{{- define "resources.ns" -}}
{{- .Release.Namespace -}}
{{- end -}}

{{/* Deep-merge an override dict onto a base spec authored as YAML.
     Lists replace wholesale — append/prepend cases stay named knobs. */}}
{{- define "resources.mergeSpec" -}}
{{- toYaml (mergeOverwrite (fromYaml (index . 0)) (deepCopy (index . 1))) -}}
{{- end -}}
