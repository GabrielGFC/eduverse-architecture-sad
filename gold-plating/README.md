# Gold Plating — Artefatos Extras (Fase 3)

Esta pasta entrega excelência técnica acima do mínimo exigido, com artefatos **executáveis e versionados** — não apenas planos.

## 📦 Conteúdo entregue

### 1. `terraform/` — Infraestrutura como Código (AWS)

| Arquivo | Conteúdo |
|---|---|
| [`terraform/main.tf`](terraform/main.tf) | Provisiona VPC Multi-AZ, RDS Multi-AZ, ElastiCache, ECS Fargate Cluster, Lambda + IAM, EventBridge bus, SQS + DLQs |
| [`terraform/variables.tf`](terraform/variables.tf) | Variáveis tipadas e sensíveis isoladas |
| [`terraform/dev.tfvars.example`](terraform/dev.tfvars.example) | Template de configuração para `dev` |
| [`terraform/modules/fargate-service/main.tf`](terraform/modules/fargate-service/main.tf) | Módulo reutilizável: task definition + service + autoscaling horizontal por CPU |

**Como aplicar:**
```bash
cd gold-plating/terraform
cp dev.tfvars.example dev.tfvars   # editar com valores reais
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### 2. `observability/` — Monitoramento e Alarms

| Arquivo | Conteúdo |
|---|---|
| [`observability/cloudwatch-dashboard.json`](observability/cloudwatch-dashboard.json) | Dashboard com 7 widgets: latência API GW, CPU Fargate, Lambda errors, SQS depth, Circuit Breaker state, RDS, EventBridge |
| [`observability/alarms.tf`](observability/alarms.tf) | 6 alarms críticos vinculados ao SNS on-call, cada um apontando para uma seção do runbook |

**Alarms cobertos:** Circuit Breaker open sustained, SQS mensagem antiga, DLQ não-vazia, RDS storage baixo, Lambda error rate, API Gateway 5xx.

### 3. `chaos/` — Chaos Engineering

[`chaos/scenarios.md`](chaos/scenarios.md) — 5 cenários com **hipótese formal**, falha injetada, métricas de validação e critério de sucesso/falha. Executáveis via AWS FIS. Cada cenário valida uma decisão do [ADR-0002](../docs/adrs/0002-padrao-resiliencia.md).

### 4. `diagrams-extra/` — Diagramas adicionais (Mermaid)

| Arquivo | Tipo | Cobre |
|---|---|---|
| [`diagrams-extra/sequence-assessment-submit.mmd`](diagrams-extra/sequence-assessment-submit.mmd) | Sequence | Submissão de avaliação (síncrono + Outbox + eventos) |
| [`diagrams-extra/sequence-recommendation-async.mmd`](diagrams-extra/sequence-recommendation-async.mmd) | Sequence | Recomendação assíncrona (cache miss, retry, DLQ) |
| [`diagrams-extra/deployment-aws.mmd`](diagrams-extra/deployment-aws.mmd) | Deployment | Topologia AWS completa (VPC, subnets, serviços, observabilidade) |
| [`diagrams-extra/c4-l3-adaptive-learning.mmd`](diagrams-extra/c4-l3-adaptive-learning.mmd) | C4 Nível 3 | Components internos do `adaptive-learning-service` (Hexagonal) |

### 5. `docs-extra/` — Documentação operacional

| Arquivo | Conteúdo |
|---|---|
| [`docs-extra/runbook-oncall.md`](docs-extra/runbook-oncall.md) | Runbook estruturado por alarm — ação imediata, comunicação, pós-incidente |
| [`docs-extra/dr-plan.md`](docs-extra/dr-plan.md) | Plano de Disaster Recovery — RTO/RPO formais, 4 cenários, procedimentos, plano de teste |
| [`docs-extra/cost-optimization.md`](docs-extra/cost-optimization.md) | Estimativa mensal, cenário de pico, 7 estratégias de otimização, anti-padrões evitados |

---

## Por que isso vale como gold plating?

- **Não é doc decorativa** — é Terraform aplicável, JSON de dashboard importável, runbook acionável.
- **Cada artefato é rastreável** a uma decisão de ADR específica (0001, 0002 ou 0003).
- **Cobre o ciclo operacional completo**: provisionar (Terraform) → observar (dashboard + alarms) → reagir (runbook) → recuperar (DR plan) → testar (chaos) → otimizar (cost).
- **Pronto para evoluir**: módulos Terraform reutilizáveis, alarms parametrizados por ambiente.
