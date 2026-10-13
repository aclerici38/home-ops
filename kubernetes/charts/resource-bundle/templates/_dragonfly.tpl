{{- define "resources.dragonfly.spec" -}}
{{- /* Appended to args below; a merge would replace the whole list. */ -}}
{{- $extraArgs := dig "extraArgs" list .Values.dragonfly -}}
image: ghcr.io/dragonflydb/dragonfly:v1.40.1@sha256:ebf3c6c213e82fb51b4521660cca13f06f3421dc5b1ed14f2f474c50b5e29986
replicas: 3
env:
  - name: MAX_MEMORY
    valueFrom:
      resourceFieldRef:
        resource: limits.memory
        divisor: 1Mi
args:
  {{- concat (list
        "--maxmemory=$(MAX_MEMORY)Mi"
        "--dbnum=1"
        "--dbfilename="
        "--proactor_threads=4"
        "--version_check=false"
        "--cluster_mode=emulated"
        "--lock_on_hashtags") $extraArgs | toYaml | nindent 2 }}
resources:
  requests: {cpu: 100m}
  limits: {memory: 1Gi}
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
{{- end -}}

{{- define "resources.dragonfly.podLabels" -}}
{{- toYaml (dig "podLabels" (dict "app.kubernetes.io/instance" (include "resources.app" .)) .Values.dragonfly) -}}
{{- end -}}

{{- /* Clients on 6379; the operator and replicas only ever use the admin port. */}}
{{- define "resources.dragonfly.networkPolicySpec" -}}
{{- $db := printf "%s-dragonfly-db" (include "resources.app" .) -}}
endpointSelector:
  matchLabels:
    app: {{ $db }}
ingress:
  - fromEndpoints:
      - matchLabels:
          {{- include "resources.dragonfly.podLabels" . | nindent 10 }}
    toPorts:
      - ports:
          - {port: "6379", protocol: TCP}
  - fromEndpoints:
      - matchLabels:
          app: {{ $db }}
      - matchLabels:
          k8s:io.kubernetes.pod.namespace: dragonfly-operator
          app.kubernetes.io/name: dragonfly-operator
    toPorts:
      - ports:
          - {port: "9999", protocol: TCP}
egress:
  - toEndpoints:
      - matchLabels:
          app: {{ $db }}
    toPorts:
      - ports:
          - {port: "9999", protocol: TCP}
{{- end -}}

{{- /* Allow-only, like <app>-postgres: the app's own policy decides enforcement. */}}
{{- define "resources.dragonfly.clientNetworkPolicySpec" -}}
endpointSelector:
  matchLabels:
    {{- include "resources.dragonfly.podLabels" . | nindent 4 }}
enableDefaultDeny:
  ingress: false
  egress: false
egress:
  - toEndpoints:
      - matchLabels:
          app: {{ include "resources.app" . }}-dragonfly-db
    toPorts:
      - ports:
          - {port: "6379", protocol: TCP}
{{- end -}}
