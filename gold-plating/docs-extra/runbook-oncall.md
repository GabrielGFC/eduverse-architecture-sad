# Runbook On-Call — EduVerse Fase 3

Cada seção corresponde a **um alarm** definido em [`gold-plating/observability/alarms.tf`](../observability/alarms.tf). Ordem: **avaliar → mitigar → comunicar → investigar**.

> **Princípio:** o on-call não diagnostica causa-raiz no meio da madrugada. Ele **restaura serviço** e abre incidente para análise no horário comercial.

---

## 1. `eduverse-breaker-open-sustained` — Circuit Breaker aberto > 5min

**O que significa:** uma dependência externa (IA, Moodle ou Content) está falhando consistentemente. O sistema está **degradado, não caído** — usuários veem fallback estático.

**Ação imediata (< 10min)**
1. Identificar a dependência: ver dimensão `Dependency` no alarm.
2. Validar lado externo: `curl -m 5` no endpoint da dependência a partir de uma instância Fargate.
3. Se externo está OK → o problema é interno (timeout muito baixo, credencial expirada). Pular para passo 5.
4. Se externo está down → comunicar (passo abaixo) e aguardar; sistema já está em fallback.
5. Verificar `Secrets Manager` para credenciais expiradas: `aws secretsmanager list-secrets --filters Key=name,Values=eduverse`.
6. Se identificou credencial expirada: rotacionar e forçar deploy do serviço afetado.

**Comunicar:** Slack `#eduverse-incidents`, template `INC-degradacao-IA`. Se durar > 30min, escalar para coordenação pedagógica.

**Pós-incidente:** abrir ticket no backlog para revisar thresholds do breaker e adicionar fallback adicional se aplicável.

---

## 2. `eduverse-sqs-old-*` — Mensagem antiga > 15min em fila SQS

**O que significa:** consumidor está lento, parado ou enfileiramento está acima da capacidade.

**Ação imediata**
1. Métricas do consumidor: `aws lambda get-function --function-name eduverse-integrations-prod` — checar Throttles e Erros recentes.
2. Se Throttle: aumentar `reserved_concurrent_executions` temporariamente:
   ```bash
   aws lambda put-function-concurrency \
     --function-name eduverse-integrations-prod \
     --reserved-concurrent-executions 100
   ```
3. Se Erro: ir para seção 5 (lambda error rate).
4. Se nenhum dos dois e fila continuando a crescer → problema no schema do evento. Inspecionar 1 mensagem:
   ```bash
   aws sqs receive-message --queue-url <url> --max-number-of-messages 1
   ```

**Comunicar:** Slack se atraso projetado > 30min.

---

## 3. `eduverse-dlq-*` — Mensagens chegando em DLQ

**O que significa:** falha persistente após 5 retries. **Mensagem está parada — não foi perdida.**

**Ação imediata**
1. **NÃO redirecionar para fila principal sem investigar.** Pode reabrir o bug em massa.
2. Coletar 1 mensagem da DLQ e inspecionar payload:
   ```bash
   aws sqs receive-message --queue-url <dlq-url> --attribute-names All --message-attribute-names All
   ```
3. Procurar nos CloudWatch Logs do consumidor a partir do `correlationId` do envelope CloudEvents:
   ```
   fields @timestamp, @message | filter correlationId = "X" | sort @timestamp asc
   ```
4. Classificar:
   - **Bug de schema** (campo novo, breaking change) → abrir bug P1, comunicar produtor, manter DLQ até fix.
   - **Dado corrompido pontual** → mover manualmente para arquivo morto, registrar caso.
   - **Falha transitória de dependência externa** → reprocessar via:
     ```bash
     aws sqs start-message-move-task --source-arn <dlq-arn> --destination-arn <main-q-arn>
     ```

**Comunicar:** sempre. DLQ não-vazia é sempre incidente.

---

## 4. `eduverse-rds-storage-low` — RDS com < 10GB livre

**O que significa:** banco vai parar de aceitar escrita em horas.

**Ação imediata (< 30min)**
1. Aumentar storage:
   ```bash
   aws rds modify-db-instance \
     --db-instance-identifier eduverse-prod \
     --allocated-storage 100 \
     --apply-immediately
   ```
   *Storage scaling é online no RDS — não causa downtime.*
2. Validar `max_allocated_storage` no Terraform (atualmente 200GB). Se já no teto, escalar urgente.
3. Investigar consumo: `aws rds describe-pending-maintenance-actions` + query `pg_database_size`.

**Pós-incidente:** revisar política de retenção de auditoria; talvez migrar logs antigos para S3.

---

## 5. `eduverse-lambda-error-rate` — Lambda integrations > 5% erro em 10min

**Ação imediata**
1. CloudWatch Logs Insights:
   ```
   fields @timestamp, @message
     | filter @message like /ERROR/
     | stats count() by errorType
     | sort count() desc
   ```
2. Erros do tipo `Timeout` → ver seção 1 (provavelmente IA/Moodle lento).
3. Erros do tipo `ValidationException` → bug recente, considerar rollback:
   ```bash
   aws lambda update-function-code \
     --function-name eduverse-integrations-prod \
     --s3-bucket eduverse-artifacts \
     --s3-key integrations/previous-stable.zip
   ```
4. Erros do tipo `AccessDenied` → IAM. Checar política recém-aplicada via CloudTrail.

---

## 6. `eduverse-apigw-5xx` — API Gateway > 1% de 5xx

**O que significa:** algum backend (Fargate) está retornando 5xx OU API Gateway tem problema interno.

**Ação imediata**
1. Filtrar 5xx por endpoint:
   ```
   fields @timestamp, status, path, integrationStatus
     | filter status >= 500
     | stats count() by path
     | sort count() desc
   ```
2. Endpoint específico (90% dos 5xx vêm dele) → checar saúde do serviço target group:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```
3. Tasks unhealthy → forçar redeploy:
   ```bash
   aws ecs update-service --cluster eduverse-prod --service <name> --force-new-deployment
   ```
4. Saúde OK mas 5xx persistindo → ver logs do serviço para erro de aplicação. Considerar rollback.

---

## Convenções

- **CorrelationId** está em TODA mensagem/request — usar como chave de busca cross-service.
- **Severidade alta** = afeta avaliação ou login. **Severidade média** = afeta recomendação ou notificação. **Severidade baixa** = afeta dashboard secundário.
- **Pós-mortem obrigatório** para SEV-alto, em até 48h, blameless, no template `docs/postmortems/`.
