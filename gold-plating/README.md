# Gold Plating — Artefatos Extras

Esta pasta concentra entregas opcionais que demonstram excelência técnica acima do mínimo exigido para a Fase 3. Cada item abaixo é independente e pode ser avaliado isoladamente.

## Conteúdo planejado

### 1. `terraform/` — Infraestrutura como Código

Provisionamento completo da arquitetura AWS descrita no [ADR-0001](../docs/adrs/0001-estrategia-nuvem.md):

- VPC com 3 AZ, subnets públicas/privadas
- ECS Fargate cluster + Application Load Balancer
- RDS PostgreSQL Multi-AZ
- ElastiCache Redis
- API Gateway + CloudFront + WAF
- EventBridge bus + SQS queues + DLQ
- Lambda functions para `integrations-service`
- IAM roles com princípio do menor privilégio
- CloudWatch dashboards e alarms

### 2. `observability/` — Dashboards e Alarms

Configuração JSON de dashboards CloudWatch cobrindo:

- Estado dos Circuit Breakers (open / half-open / closed) por serviço
- Profundidade de filas SQS e idade da mensagem mais antiga
- Latência p50/p95/p99 por endpoint do API Gateway
- Taxa de retry e duração de execução por Lambda
- Capacidade Fargate (CPU, memória, contagem de tasks)

Alarms críticos:

- `CircuitBreakerOpenSustained > 5min` → SNS para on-call
- `SQS_OldestMessageAge > 15min` → SNS
- `RDS_FreeStorageSpace < 20%` → SNS
- `Lambda_ErrorRate > 5% em 10min` → SNS

### 3. `chaos/` — Chaos Engineering

Cenários de injeção de falha para validar os padrões do [ADR-0002](../docs/adrs/0002-padrao-resiliencia.md):

- **IA fora do ar:** verifica fallback degradado em `adaptive-learning-service`
- **Moodle com latência 5s:** verifica abertura de Circuit Breaker
- **Pico de submissão de avaliação:** valida rate limiting no API Gateway
- **Falha de uma AZ:** verifica failover RDS Multi-AZ

Implementados via **AWS Fault Injection Simulator (FIS)** ou scripts shell de degradação controlada.

### 4. `diagrams-extra/` — Diagramas adicionais

- **Sequence diagram** do fluxo de submissão de avaliação (síncrono + evento)
- **Sequence diagram** do recálculo de recomendação (totalmente assíncrono)
- **Deployment diagram** AWS detalhado
- **C4 Nível 3 (Components)** do `adaptive-learning-service`

### 5. `docs-extra/`

- **Runbook on-call**: ações para cada alarm acima
- **Disaster Recovery plan**: RPO/RTO por serviço, processo de restore RDS
- **Cost optimization report**: estimativa mensal e cenários de tuning

---

> Esta seção é evolutiva. Itens são adicionados conforme implementados, com PR vinculado a uma issue rastreável.
