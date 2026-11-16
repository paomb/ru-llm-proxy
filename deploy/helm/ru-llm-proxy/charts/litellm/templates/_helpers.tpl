{{- define "litellm.fullname" -}}
{{- printf "%s-litellm" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "litellm.selectorLabels" -}}
app.kubernetes.io/name: litellm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: litellm
{{- end -}}

{{- define "litellm.jobsSelectorLabels" -}}
app.kubernetes.io/name: litellm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: litellm-jobs
{{- end -}}

{{- define "litellm.image" -}}
{{- $registry := .Values.global.imageRegistry | default "" -}}
{{- $repo := printf "%s%s" $registry .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (required "litellm.image.tag обязателен; latest запрещён" .Values.image.tag) -}}
{{- end -}}
{{- end -}}

{{- define "litellm.commonEnv" -}}
{{- include "ru-llm-proxy.proxyEnv" . }}
- name: PYTHONPATH
  value: /app
- name: LITELLM_MODE
  value: PRODUCTION
- name: DISABLE_AIOHTTP_TRANSPORT
  value: "True"
- name: AIOHTTP_TRUST_ENV
  value: "True"
- name: DISABLE_SCHEMA_UPDATE
  value: "true"    # миграции — только pre-install/pre-upgrade Job
{{- if not .Values.global.vault.enabled }}
{{- /* Режим existingSecret: секреты из Kubernetes Secret */ -}}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ required "global.external.postgres.litellm.existingSecret обязателен при vault.enabled=false" .Values.global.external.postgres.litellm.existingSecret }}
      key: url
- name: REDIS_HOST
  value: {{ required "global.external.redis.host обязателен при vault.enabled=false" .Values.global.external.redis.host | quote }}
- name: REDIS_PORT
  value: {{ .Values.global.external.redis.port | default 6379 | quote }}
- name: REDIS_URL
  value: {{ printf "redis://%s:%v" .Values.global.external.redis.host (.Values.global.external.redis.port | default 6379) | quote }}
{{- if .Values.global.external.redis.existingSecret }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.external.redis.existingSecret }}
      key: password
{{- end }}
- name: LITELLM_MASTER_KEY
  valueFrom:
    secretKeyRef:
      name: {{ required "global.secrets.litellm.existingSecret обязателен при vault.enabled=false" .Values.global.secrets.litellm.existingSecret }}
      key: master-key
- name: LITELLM_SALT_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: salt-key
- name: UI_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: ui-username
- name: UI_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: ui-password
- name: ZAI_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: zai-api-key
- name: ZAI_API_KEY_2
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: zai-api-key-2
      optional: true
- name: OPENAI_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: openai-api-key
      optional: true
- name: ANTHROPIC_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: anthropic-api-key
      optional: true
- name: CODEX_LB_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.secrets.litellm.existingSecret }}
      key: codex-lb-api-key
      optional: true
{{- else }}
{{- /* Режим Vault: секреты из /vault/secrets/*.env, source в entrypoint */ -}}
- name: VAULT_SECRETS_DIR
  value: /vault/secrets
{{- end }}
- name: DISABLE_ADMIN_UI
  value: {{ .Values.config.disableAdminUi | quote }}
- name: PRESIDIO_ANALYZER_URL
  value: {{ printf "http://%s-presidio-analyzer:5001" .Release.Name | quote }}
- name: PII_GUARDRAIL_MODE
  value: {{ .Values.config.piiGuardrailMode | quote }}
- name: PII_GUARDRAIL_FAILURE_MODE
  value: {{ .Values.config.piiGuardrailFailureMode | quote }}
- name: PII_MAPPING_TTL_SECONDS
  value: {{ .Values.config.piiMappingTtlSeconds | quote }}
- name: PRE_EGRESS_POLICY_MODE
  value: {{ .Values.config.preEgressPolicyMode | quote }}
- name: FINAL_PAYLOAD_LEAK_CHECK_MODE
  value: {{ .Values.config.finalPayloadLeakCheckMode | quote }}
- name: DICTIONARY_SUBSTITUTIONS_ENABLED
  value: {{ .Values.config.dictionarySubstitutionsEnabled | quote }}
- name: DICTIONARY_SUBSTITUTIONS_FILE
  value: /app/litellm_guardrails/dictionary-substitutions.default.json
- name: REGULATED_TOPIC_POLICY_MODE
  value: {{ .Values.config.regulatedTopicPolicyMode | quote }}
- name: SYNTHETIC_PII_ALLOWLIST_MODE
  value: {{ .Values.config.syntheticPiiAllowlistMode | quote }}
- name: PII_GUARDRAIL_ANALYZER_TIMEOUT_SECONDS
  value: {{ .Values.config.analyzerTimeoutSeconds | quote }}
- name: PII_GUARDRAIL_ANALYZER_MAX_CONNECTIONS
  value: {{ .Values.config.analyzerMaxConnections | quote }}
- name: PII_GUARDRAIL_REDIS_MAX_CONNECTIONS
  value: {{ .Values.config.redisMaxConnections | quote }}
{{- end -}}
