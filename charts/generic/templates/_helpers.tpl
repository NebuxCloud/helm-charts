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


{{/* The release's only service, for a backendRef that names none. */}}
{{- define "nebux-generic.defaultBackend" -}}
{{- if eq (len .Values.workloads) 1 -}}
{{ include "nebux-generic.name" (dict "root" . "kind" "workloads" "key" (keys .Values.workloads | first)) }}
{{- else -}}
{{- fail "a backendRef must name its service: this release has no single default" -}}
{{- end -}}
{{- end -}}

{{/* Render what Kubernetes wants comma-separated, from a list or a string. */}}
{{- define "nebux-generic.csv" -}}
{{- if kindIs "string" . -}}
{{ . }}
{{- else -}}
{{ join "," . }}
{{- end -}}
{{- end -}}
