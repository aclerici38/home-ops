{{/* Takes one normalized target: {name, kind, replicas}. */}}
{{- define "resources.nfsGate.spec" -}}
scaleTargetRef:
  apiVersion: apps/v1
  kind: {{ .kind }}
  name: {{ .name }}
minReplicas: 0
maxReplicas: {{ .replicas }}
metrics:
  - type: External
    external:
      metric:
        name: nfs_available
      target:
        # nfs_available is 0|1, so desired = ceil(1 / (1/replicas)) = replicas, or 0.
        type: AverageValue
        averageValue: {{ printf "%dm" (div 1000 (int .replicas)) | quote }}
behavior:
  scaleDown:
    stabilizationWindowSeconds: 0
  scaleUp:
    # Let nfs-server settle before remounting.
    stabilizationWindowSeconds: 60
{{- end -}}
