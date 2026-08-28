{{- define "resources.dragonfly.spec" -}}
{{- /* Appended to args below. Stays a knob because a merge REPLACES a list, so
       spec.args would mean restating all eight defaults to add one flag. */ -}}
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
