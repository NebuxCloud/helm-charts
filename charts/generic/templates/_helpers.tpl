{{/*
Resolve a reference to a named resource using the "@" convention.

A name prefixed with "@" is release-managed: the release name is prepended,
and the remainder (if any) is appended as a suffix. A bare "@" resolves to the
release name alone. Any other name is used verbatim, allowing references to
resources outside this release.

Usage:
  {{ include "nebux-generic.resourceName" (dict "name" $name "release" $.Release.Name) }}
*/}}
{{- define "nebux-generic.resourceName" -}}
{{- if hasPrefix "@" .name -}}
{{ .release }}{{ if ne .name "@" }}-{{ trimPrefix "@" .name }}{{ end }}
{{- else -}}
{{ .name }}
{{- end -}}
{{- end -}}

{{/*
Resolve a namespace using the "@" convention.

A bare "@" resolves to the release namespace; any other value is used verbatim.

Usage:
  {{ include "nebux-generic.namespace" (dict "namespace" $namespace "release" $.Release.Namespace) }}
*/}}
{{- define "nebux-generic.namespace" -}}
{{- if eq .namespace "@" -}}
{{ .release }}
{{- else -}}
{{ .namespace }}
{{- end -}}
{{- end -}}

{{/*
Resolve a reference to a release-managed config map or secret using the "@"
convention, mirroring how those resources are named.

A name prefixed with "@" is release-managed: the release name is prepended, and
the key (the remainder) is only appended as a suffix when more than one config
map/secret of that kind is defined (matching the naming in config-map.yml and
secret.yml). Any other name is used verbatim, allowing references to config
maps/secrets outside this release.

Usage:
  {{ include "nebux-generic.configRef" (dict "name" $name "release" $.Release.Name "count" (len $.Values.secrets)) }}
*/}}
{{- define "nebux-generic.configRef" -}}
{{- if hasPrefix "@" .name -}}
{{ .release }}{{ if gt (int .count) 1 }}-{{ trimPrefix "@" .name }}{{ end }}
{{- else -}}
{{ .name }}
{{- end -}}
{{- end -}}
