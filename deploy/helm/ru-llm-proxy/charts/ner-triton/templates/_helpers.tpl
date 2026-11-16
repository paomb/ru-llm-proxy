{{- define "ner-triton.fullname" -}}
{{- printf "%s-ner-triton" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ner-triton.selectorLabels" -}}
app.kubernetes.io/name: ner-triton
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: ner-triton
{{- end -}}

{{- define "ner-triton.image" -}}
{{- $repo := printf "%s%s" (.Values.global.imageRegistry | default "") .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (required "ner-triton.image.tag обязателен" .Values.image.tag) -}}
{{- end -}}
{{- end -}}
