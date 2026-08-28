{{- define "resources.gpu.spec" -}}
spec:
  devices:
    requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.intel.com
          adminAccess: true
          allocationMode: All
{{- end -}}
