{{- define "presidio-analyzer.fullname" -}}
{{- printf "%s-presidio-analyzer" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "presidio-analyzer.selectorLabels" -}}
app.kubernetes.io/name: presidio-analyzer
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: presidio-analyzer
{{- end -}}

{{- define "presidio-analyzer.image" -}}
{{- $repo := printf "%s%s" (.Values.global.imageRegistry | default "") .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (required "presidio-analyzer.image.tag обязателен" .Values.image.tag) -}}
{{- end -}}
{{- end -}}
