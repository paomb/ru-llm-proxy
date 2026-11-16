#!/bin/sh
set -eu

# Загрузка секретов из Vault Agent Injector (при vault.enabled=true в Helm chart).
# Файлы /vault/secrets/*.env содержат export KEY="value" строки.
if [ -n "${VAULT_SECRETS_DIR:-}" ] && [ -d "${VAULT_SECRETS_DIR}" ]; then
    for f in "${VAULT_SECRETS_DIR}"/*.env; do
        [ -f "$f" ] && . "$f"
    done
fi

if [ "${USE_DDTRACE:-false}" = "true" ]; then
    export DD_TRACE_OPENAI_ENABLED="False"
    exec ddtrace-run python -m litellm_guardrails.server "$@"
fi
exec python -m litellm_guardrails.server "$@"
