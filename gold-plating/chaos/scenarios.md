# Chaos Engineering — Cenários do EduVerse

Cada cenário valida **uma hipótese de resiliência** definida no [ADR-0002](../../docs/adrs/0002-padrao-resiliencia.md). Sem hipótese explícita, não é chaos engineering — é só bagunça. Execução via **AWS Fault Injection Simulator (FIS)** em ambiente `staging` durante janela de baixa demanda.

## Cenário 1 — Motor de IA fora do ar

| Campo | Valor |
|---|---|
| Hipótese | Quando o motor de IA fica indisponível, o `adaptive-learning-service` abre o Circuit Breaker em < 30s e passa a entregar **trilha padrão** (fallback estático), sem propagar falha ao aluno. |
| Falha injetada | Bloquear egress da Security Group do Lambda para o endpoint da IA (FIS action `aws:network:block-egress`). |
| Duração | 10 minutos |
| Métrica de validação | `EduVerse/Resilience.CircuitBreakerState{Dependency=ai-recommender}` muda para 2 (open) em ≤ 30s. `5XXError` no API Gateway permanece < 0.5%. |
| Sucesso | Aluno vê banner "recomendação temporariamente indisponível, exibindo trilha padrão" — sem erro 5xx. |
| Falha | Erro 5xx no endpoint `/recommendations`, ou breaker não abre, ou pool de threads do learning-service satura. |

## Cenário 2 — Moodle com latência alta (degradação, não queda)

| Campo | Valor |
|---|---|
| Hipótese | Latência de 5s no Moodle satura **apenas** o pool Bulkhead do `LmsSyncPort`; dashboard e avaliação continuam respondendo p95 < 500ms. |
| Falha injetada | `tc qdisc add dev eth0 root netem delay 5000ms` aplicado no container do `integrations-service` para tráfego ao Moodle. |
| Duração | 15 minutos |
| Métrica de validação | Filas SQS de sync Moodle crescem (esperado), mas `Latency p95` do API Gateway em `/dashboard` permanece estável. Pool Bulkhead `lms` chega a 100% saturado sem impactar pool `ai`. |
| Sucesso | Isolamento total — só sync Moodle degrada. |
| Falha | Latência do dashboard sobe junto → Bulkhead mal dimensionado. |

## Cenário 3 — Pico de submissão de avaliação (10× a média)

| Campo | Valor |
|---|---|
| Hipótese | API Gateway rate limit absorve excesso e o `assessment-service` autoescala horizontalmente em < 3 min, mantendo p95 < 1s. |
| Falha injetada | Load test com `k6` — 1000 RPS em `POST /assessment/{id}/submit` por 10 min. |
| Métrica de validação | `429 Too Many Requests` retornado para excedente; contagem de tasks Fargate sobe de 2 para ≥ 8 em < 3min; p95 < 1s. |
| Sucesso | Nenhum 5xx; nenhuma submissão perdida (todas chegam ao banco eventualmente). |
| Falha | 5xx em cascata, ou autoscaling não dispara, ou submissões perdidas. |

## Cenário 4 — Falha de uma AZ (Multi-AZ failover)

| Campo | Valor |
|---|---|
| Hipótese | Indisponibilidade da AZ-a não afeta o serviço — Fargate roda em ≥ 2 AZ, RDS executa failover automático em < 2 min. |
| Falha injetada | FIS `aws:ec2:stop-instances` em todas as tasks Fargate da AZ-a; `aws:rds:reboot-db-instances` com failover. |
| Duração | 20 minutos |
| Métrica de validação | Downtime efetivo do API Gateway < 90s; nenhum dado perdido; RDS endpoint resolve para AZ-b. |
| Sucesso | RTO < 2min, RPO = 0 (último commit aplicado antes da falha está presente). |
| Falha | Downtime > 2min, perda de transações, ou serviços não rebalanceiam. |

## Cenário 5 — Burst de Lambda além da concorrência reservada

| Campo | Valor |
|---|---|
| Hipótese | Quando o `integrations-service` atinge concorrência máxima (50), excesso vai para SQS com retry, sem perda; alerta dispara em < 5min. |
| Falha injetada | Publicar 5000 eventos em rajada no EventBridge. |
| Métrica de validação | `Throttles` Lambda > 0, mas mensagens permanecem em SQS; DLQ permanece vazia (retry resolve). Alarm `lambda_error_rate` dispara. |
| Sucesso | Zero mensagens em DLQ; vazão restaurada após pico. |
| Falha | DLQ recebe mensagens → política de retry insuficiente ou bug de idempotência. |

## Execução

```bash
# Pré-condições: ambiente staging idêntico ao prod, monitoração ativa.
cd gold-plating/chaos
aws fis create-experiment-template --cli-input-json file://cenario-1-ia-down.json
aws fis start-experiment --experiment-template-id <id>
```

## Disciplina

- **Nunca em prod sem aprovação.**
- **Sempre com janela acordada** com stakeholders pedagógicos (evitar dia de prova).
- **Sempre com plano de rollback** documentado antes de executar.
- **Sempre seguido de post-mortem** — sucesso e falha geram aprendizado registrado.
