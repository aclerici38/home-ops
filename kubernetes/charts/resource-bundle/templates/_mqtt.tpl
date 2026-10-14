{{/* Broker identity — feeds the User and both policy halves. */}}
{{- define "resources.mqtt.ident" -}}
{{- $m := .Values.mqtt -}}
broker: {{ dig "broker" "pgmqtt" $m }}
namespace: {{ dig "brokerNamespace" "pgmqtt" $m }}
ports:
  - {port: "1883", protocol: TCP}
  {{- if dig "websocket" false $m }}
  - {port: "8083", protocol: TCP}
  {{- end }}
{{- end -}}

{{- define "resources.mqtt.podLabels" -}}
{{- toYaml (dig "podLabels" (dict "app.kubernetes.io/instance" (include "resources.app" .)) .Values.mqtt) -}}
{{- end -}}

{{- /* Without passwordFrom the broker's operator generates the password into
       <app>-mqtt-credentials (username/password/host/port/uri/ws-uri); with it,
       the operator hashes the 1Password value and writes no Secret. */}}
{{- define "resources.mqtt.userSpec" -}}
username: {{ include "resources.app" . }}
{{- if hasKey .Values.mqtt "passwordFrom" }}
passwordSecretRef:
  name: {{ include "resources.app" . }}-mqtt-password
  key: password
{{- end }}
{{- end -}}

{{- /* For apps that can't read a password from env or a file. */}}
{{- define "resources.mqtt.passwordSecretSpec" -}}
{{- $p := .Values.mqtt.passwordFrom -}}
refreshInterval: "1h"
secretStoreRef:
  kind: ClusterSecretStore
  name: onepassword-connect
data:
  - secretKey: password
    remoteRef:
      key: {{ dig "key" (include "resources.app" .) $p }}
      property: {{ required "mqtt.passwordFrom.property is required" $p.property }}
{{- end -}}

{{- /* Allow-only, like <app>-postgres: the app's own policy decides enforcement. */}}
{{- define "resources.mqtt.networkPolicySpec" -}}
{{- $i := fromYaml (include "resources.mqtt.ident" .) -}}
endpointSelector:
  matchLabels:
    {{- include "resources.mqtt.podLabels" . | nindent 4 }}
enableDefaultDeny:
  ingress: false
  egress: false
egress:
  - toEndpoints:
      - matchLabels:
          k8s:io.kubernetes.pod.namespace: {{ $i.namespace }}
          app.kubernetes.io/instance: {{ $i.broker }}
    toPorts:
      - ports:
          {{- toYaml $i.ports | nindent 10 }}
{{- end -}}

{{- /* The ingress half, in the broker's namespace; every client's policy unions
       on the broker pods, whose own policy is default-deny. */}}
{{- define "resources.mqtt.brokerNetworkPolicySpec" -}}
{{- $i := fromYaml (include "resources.mqtt.ident" .) -}}
endpointSelector:
  matchLabels:
    app.kubernetes.io/instance: {{ $i.broker }}
enableDefaultDeny:
  ingress: false
  egress: false
ingress:
  - fromEndpoints:
      - matchLabels:
          k8s:io.kubernetes.pod.namespace: {{ include "resources.ns" . }}
          {{- include "resources.mqtt.podLabels" . | nindent 10 }}
    toPorts:
      - ports:
          {{- toYaml $i.ports | nindent 10 }}
{{- end -}}
