# Ресурсы, реплики и пределы соединений Kubernetes

Исходные значения для промышленного развёртывания из задачи #59. Значения
могут быть пересмотрены после нагрузочного подтверждения (этап 5 плана).

## Запросы и пределы ресурсов

| Компонент | Реплики (min) | CPU request | CPU limit | Memory request | Memory limit |
|---|---|---|---|---|---|
| LiteLLM (serving) | 2 | 2 | 2 | 4 GiB | 4 GiB |
| LiteLLM (jobs) | 1 | 1 | 1 | 4 GiB | 4 GiB |
| Presidio Analyzer | 4 | 4 | 4 | 8 GiB | 8 GiB |
| Triton (Tiny2) | 2 | 2 | 2 | 4 GiB | 4 GiB |
| codex-lb | 3 | 200m | 1 | 256 MiB | 1 GiB |

**Суммарно (без внешних хранилищ):** ~22 vCPU requests, ~45 GiB requests.

## HPA

| Компонент | minReplicas | maxReplicas | Сигнал | scaleDown |
|---|---|---|---|---|
| LiteLLM | 2 | 6 | CPU 60% | stabilization 300s |
| Analyzer | 4 | 16 | CPU 70% + очередь (Prometheus adapter) | stabilization 600s, 1 Pod/120s |
| codex-lb | 3 | 10 | CPU 70% (штатный chart) | stabilization 300s |

**Память не используется как сигнал HPA LiteLLM**: резидентная память Prisma
отражает максимальную запись за жизнь процесса, а не текущую нагрузку.

## Пределы соединений

Пулы рассчитаны по `maxReplicas`, не по текущему числу Pod (#59).

### PostgreSQL LiteLLM

Формула: `maxReplicas × workers × database_connection_pool_limit`.

- LiteLLM serving: 6 Pod × 1 worker × 10 = 60 соединений
- LiteLLM jobs: 1 Pod × 1 worker × 10 = 10 соединений
- Миграции Job: 1–2 соединения
- **Итого: ~72 соединения** + резерв на административные операции.

### PostgreSQL codex-lb

Официальный chart: `(replicas + 1) × 2 пула × databasePoolSize`.

- codex-lb: (3 + 1) × 2 × 3 = 24 соединения (default)
- Миграции: 2 соединения
- **Итого: ~26 соединений**.

### Redis

- LiteLLM serving: 6 Pod × `PII_GUARDRAIL_REDIS_MAX_CONNECTIONS` (20) = 120
- LiteLLM jobs: 1 Pod × 20 = 20
- Analyzer: не использует Redis напрямую
- **Итого: ~140 клиентских соединений**.

### Analyzer → Triton

- Analyzer: 16 Pod × `PRESIDIO_ANALYZER_TRITON_MAX_CONNECTIONS` (default 20) = 320 HTTP-соединений к Triton Service.

## PodDisruptionBudget

Все компоненты: `maxUnavailable: 1`. При плановом обновлении или выводе узла
не допускается одновременная остановка всех экземпляров компонента (#59).

## TopologySpreadConstraints

`kubernetes.io/hostname`, `maxSkew: 1`, `whenUnsatisfiable: ScheduleAnyway` —
равномерное распределение по узлам без жёсткой блокировки при нехватке узлов.

## Миграции

- **LiteLLM**: pre-install/pre-upgrade Helm hook Job (`DISABLE_SCHEMA_UPDATE=false`),
  обслуживающие Pod имеют `DISABLE_SCHEMA_UPDATE=true`.
- **codex-lb**: штатный механизм официального chart (`config.databaseMigrateOnStartup=false`,
  миграции через отдельный Job чарта).
