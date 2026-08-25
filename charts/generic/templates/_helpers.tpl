{{/* Name a resource this chart creates, from its collection's key. */}}
{{- define "nebux-generic.name" -}}
{{ .root.Release.Name }}{{ if and .key (include "nebux-generic.isKeyed" .) }}-{{ .key }}{{ end }}
{{- end -}}

{{/* Resolve a reference: "@key" is release-managed, a bare "@" the release itself, anything else verbatim. */}}
{{- define "nebux-generic.reference" -}}
{{- if hasPrefix "@" .name -}}
{{ include "nebux-generic.name" (dict "root" .root "kind" .kind "key" (trimPrefix "@" .name)) }}
{{- else -}}
{{ .name }}
{{- end -}}
{{- end -}}

{{/* Whether a name carries its key: more than one of its kind, or "explicitNames". Without a "kind", always. */}}
{{- define "nebux-generic.isKeyed" -}}
{{- if or (not .kind) .root.Values.explicitNames (gt (len (index .root.Values .kind)) 1) }}true{{ end }}
{{- end -}}

{{/* Resolve a namespace: "@" is the release's own. */}}
{{- define "nebux-generic.namespace" -}}
{{- if eq .namespace "@" -}}
{{ .root.Release.Namespace }}
{{- else -}}
{{ .namespace }}
{{- end -}}
{{- end -}}

{{/* Render a pod's volumes. */}}
{{- define "nebux-generic.volumes" -}}
{{- range $volume := .volumes }}
- name: "{{ $volume.name }}"
  {{- if hasKey $volume "configMap" }}
  configMap:
    name: "{{ include "nebux-generic.reference" (dict "root" $.root "kind" "configMaps" "name" $volume.configMap.name) }}"
    {{- with omit $volume.configMap "name" }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if hasKey $volume "secret" }}
  secret:
    secretName: "{{ include "nebux-generic.reference" (dict "root" $.root "kind" "secrets" "name" $volume.secret.secretName) }}"
    {{- with omit $volume.secret "secretName" }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if hasKey $volume "persistentVolumeClaim" }}
  persistentVolumeClaim:
    claimName: "{{ include "nebux-generic.reference" (dict "root" $.root "kind" "persistentVolumeClaims" "name" $volume.persistentVolumeClaim.claimName) }}"
    {{- with omit $volume.persistentVolumeClaim "claimName" }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if hasKey $volume "emptyDir" }}
  {{- with $volume.emptyDir }}
  emptyDir: {{ toYaml . | nindent 4 }}
  {{- else }}
  emptyDir: {}
  {{- end }}
  {{- end }}
  {{- if hasKey $volume "hostPath" }}
  hostPath: {{ toYaml $volume.hostPath | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* The release's only service, for a backendRef that names none. */}}
{{- define "nebux-generic.defaultBackend" -}}
{{- if eq (len .Values.workloads) 1 -}}
{{ include "nebux-generic.name" (dict "root" . "kind" "workloads" "key" (keys .Values.workloads | first)) }}
{{- else -}}
{{- fail "a backendRef must name its service: this release has no single default" -}}
{{- end -}}
{{- end -}}

{{/* Render a docker config from a map of registry servers to credentials. */}}
{{- define "nebux-generic.dockerConfig" -}}
{{- $auths := dict -}}
{{- range $server, $credential := . -}}
{{- $_ := set $auths $server (dict "username" $credential.username "password" $credential.password "auth" (printf "%s:%s" $credential.username $credential.password | b64enc)) -}}
{{- end -}}
{{ dict "auths" $auths | toJson }}
{{- end -}}

{{/* Render what Kubernetes wants comma-separated, from a list or a string. */}}
{{- define "nebux-generic.csv" -}}
{{- if kindIs "string" . -}}
{{ . }}
{{- else -}}
{{ join "," . }}
{{- end -}}
{{- end -}}
