{{- define "ru-llm-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ru-llm-proxy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ru-llm-proxy.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ru-llm-proxy
{{- end -}}

{{- define "ru-llm-proxy.componentLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Аннотации Vault Agent Injector. Применяется к Pod'ам при vault.enabled=true.
Секреты пишутся в /vault/secrets/<name>.env в формате export KEY="value".
*/}}
{{- define "ru-llm-proxy.vaultAnnotations" -}}
{{- if .Values.global.vault.enabled }}
{{- $annotations := dict }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject" "true" }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-pre-populate-only" "true" }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-init-first" "true" }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-requests-cpu" .Values.global.vault.agentResources.requests.cpu }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-requests-mem" .Values.global.vault.agentResources.requests.memory }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-limits-cpu" .Values.global.vault.agentResources.limits.cpu }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-limits-mem" .Values.global.vault.agentResources.limits.memory }}
{{- $_ := set $annotations "vault.hashicorp.com/role" .Values.global.vault.role }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-service-account-token-volume-name" "vault-token" }}

{{- /* LiteLLM секреты */ -}}
{{- $litellmPath := .Values.global.vault.paths.litellm }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-secret-litellm.env" $litellmPath }}
{{- $litellmTpl := printf "{{- with secret \"%s\" -}}\n" $litellmPath }}
{{- $litellmTpl = printf "%s{{ range $Key, $Value := .Data.data }}" $litellmTpl }}
{{- $litellmTpl = printf "%sexport {{$Key}}=\"{{$Value}}\"\n" $litellmTpl }}
{{- $litellmTpl = printf "%s{{ end }}\n{{- end -}}" $litellmTpl }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-template-litellm.env" $litellmTpl }}

{{- /* PostgreSQL LiteLLM */ -}}
{{- $pgPath := .Values.global.vault.paths.postgresLitellm }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-secret-postgres-litellm.env" $pgPath }}
{{- $pgTpl := printf "{{- with secret \"%s\" -}}\n" $pgPath }}
{{- $pgTpl = printf "%s{{ range $Key, $Value := .Data.data }}" $pgTpl }}
{{- $pgTpl = printf "%sexport {{$Key}}=\"{{$Value}}\"\n" $pgTpl }}
{{- $pgTpl = printf "%s{{ end }}\n{{- end -}}" $pgTpl }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-template-postgres-litellm.env" $pgTpl }}

{{- /* Redis */ -}}
{{- $redisPath := .Values.global.vault.paths.redis }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-secret-redis.env" $redisPath }}
{{- $redisTpl := printf "{{- with secret \"%s\" -}}\n" $redisPath }}
{{- $redisTpl = printf "%s{{ range $Key, $Value := .Data.data }}" $redisTpl }}
{{- $redisTpl = printf "%sexport {{$Key}}=\"{{$Value}}\"\n" $redisTpl }}
{{- $redisTpl = printf "%s{{ end }}\n{{- end -}}" $redisTpl }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-template-redis.env" $redisTpl }}

{{- /* Общие секреты контура (опционально) */ -}}
{{- if .Values.global.vault.sharedPath }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-secret-shared.env" .Values.global.vault.sharedPath }}
{{- $sharedTpl := printf "{{- with secret \"%s\" -}}\n" .Values.global.vault.sharedPath }}
{{- $sharedTpl = printf "%s{{ range $Key, $Value := .Data.data }}" $sharedTpl }}
{{- $sharedTpl = printf "%sexport {{$Key}}=\"{{$Value}}\"\n" $sharedTpl }}
{{- $sharedTpl = printf "%s{{ end }}\n{{- end -}}" $sharedTpl }}
{{- $_ := set $annotations "vault.hashicorp.com/agent-inject-template-shared.env" $sharedTpl }}
{{- end }}

{{- toYaml $annotations }}
{{- end }}
{{- end -}}

{{/*
Volume для Vault service account token (projected).
*/}}
{{- define "ru-llm-proxy.vaultTokenVolume" -}}
{{- if .Values.global.vault.enabled }}
- name: vault-token
  projected:
    sources:
      - serviceAccountToken:
          path: vault-token
          expirationSeconds: 7200
          audience: vault
{{- end }}
{{- end -}}

{{/*
VolumeMount для Vault token.
*/}}
{{- define "ru-llm-proxy.vaultTokenMount" -}}
{{- if .Values.global.vault.enabled }}
- name: vault-token
  mountPath: /var/run/secrets/tokens
{{- end }}
{{- end -}}
{{- define "ru-llm-proxy.proxyEnv" -}}
{{- if .Values.global.proxy.httpProxy }}
{{- $noProxyBase := printf "localhost,127.0.0.1,.svc,.svc.cluster.local,.cluster.local,%s-litellm,%s-presidio-analyzer,%s-ner-triton,%s-codex-lb" .Release.Name .Release.Name .Release.Name .Release.Name -}}
{{- $noProxy := $noProxyBase -}}
{{- if .Values.global.proxy.noProxy }}
{{- $noProxy = printf "%s,%s" $noProxyBase .Values.global.proxy.noProxy -}}
{{- end }}
- name: HTTP_PROXY
  value: {{ .Values.global.proxy.httpProxy | quote }}
- name: HTTPS_PROXY
  value: {{ .Values.global.proxy.httpsProxy | default .Values.global.proxy.httpProxy | quote }}
- name: NO_PROXY
  value: {{ $noProxy | quote }}
- name: http_proxy
  value: {{ .Values.global.proxy.httpProxy | quote }}
- name: https_proxy
  value: {{ .Values.global.proxy.httpsProxy | default .Values.global.proxy.httpProxy | quote }}
- name: no_proxy
  value: {{ $noProxy | quote }}
{{- end }}
{{- end -}}
