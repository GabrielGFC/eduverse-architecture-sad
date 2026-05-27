# Cost Optimization Report — EduVerse Fase 3

## Estimativa mensal (cenário base — 500 usuários ativos diários)

| Serviço | Configuração | Custo USD/mês |
|---|---|---|
| ECS Fargate | 3 serviços × 2 tasks (0.5 vCPU, 1 GB médio), 24/7 | ~52 |
| Lambda integrations | 500k invocações, 512MB, 800ms médio | ~3 |
| RDS PostgreSQL Multi-AZ | db.t4g.medium, 50GB gp3 | ~110 |
| ElastiCache Redis | 2 × cache.t4g.small | ~30 |
| API Gateway | 1M requests | ~3.5 |
| CloudFront | 50 GB egress | ~5 |
| EventBridge | 200k eventos | ~0.20 |
| SQS | 500k mensagens | ~0.20 |
| DynamoDB | on-demand, 1M leituras/500k escritas | ~2 |
| CloudWatch Logs + Metrics + X-Ray | 50GB ingest + 10 dashboards + 1M traces | ~30 |
| NAT Gateway | 1 NAT + 30 GB egress | ~38 |
| Data transfer cross-AZ | ~15 |
| **Total base** | | **~290 USD/mês** |

## Cenário pico (semana de prova, +5×)

| Recurso | Impacto | Custo adicional |
|---|---|---|
| Fargate autoscaling (8 tasks médio) | +CPU/RAM | +80 USD |
| Lambda burst (2.5M invocações) | | +12 USD |
| RDS storage IOPS | | +10 USD |
| **Adicional** | | **~+100 USD em semana de pico** |

## Estratégias de otimização aplicadas

1. **Fargate Spot para `adaptive-learning-service`**
   - Workload tolerante a interrupção (cache absorve).
   - Economia esperada: **40% sobre o custo Fargate** desse serviço (~12 USD/mês).

2. **NAT Gateway compartilhado vs. por AZ**
   - Em `dev`: 1 NAT (já configurado em `main.tf` via `single_nat_gateway`).
   - Em `prod`: avaliar VPC Endpoints (S3, DynamoDB, ECR, Secrets Manager) — elimina egress NAT para esses serviços. **Economia: ~60% do custo NAT (~22 USD/mês).**

3. **CloudWatch Logs retenção**
   - 30 dias para logs operacionais (atual).
   - 7 dias para logs de access do API Gateway (alto volume, baixo valor histórico).
   - **Economia: ~30% do custo Logs (~9 USD/mês).**

4. **RDS reserved instance (1 ano, no upfront)**
   - Quando consumo se estabilizar: ~38% de desconto sobre RDS. **Economia: ~42 USD/mês.**

5. **Lambda ARM (Graviton)**
   - Migrar `integrations-service` para runtime ARM: 20% mais barato e 19% mais rápido.

6. **DynamoDB on-demand → provisioned com auto-scaling**
   - Quando volume previsível: ~50% mais barato em padrão constante.

7. **Budget Alarms (obrigatório dia 1)**
   ```bash
   aws budgets create-budget --account-id <id> \
     --budget '{"BudgetName":"eduverse-monthly","BudgetLimit":{"Amount":"500","Unit":"USD"}}' \
     --notifications-with-subscribers file://budget-alerts.json
   ```
   Alertas em 50%, 80% e 100% do budget — antes de virar surpresa.

## Anti-padrões evitados

- ❌ Manter Fargate em on-demand para cargas previsíveis (usar Spot ou Compute Savings Plan).
- ❌ Logar tudo em CloudWatch (alguns logs vão para S3 + Athena — 10× mais barato).
- ❌ NAT Gateway por AZ em `dev` (1 basta).
- ❌ Subir RDS em `prod` sem reserved instance após 3 meses de estabilidade.

## Revisão

- **Semanal:** dashboard de custo no Cost Explorer.
- **Mensal:** relatório de tendência e ajuste de instance class.
- **Trimestral:** revisão de reservation/savings plans.
