# Plano de Disaster Recovery — EduVerse Fase 3

## Objetivos formais

| Serviço | RTO (tempo para voltar) | RPO (perda máxima de dado) | Justificativa |
|---|---|---|---|
| `identity-service` | 15 min | 0 (síncrono replicado) | Sem login, sistema inteiro indisponível |
| `assessment-service` | 30 min | 5 min | Avaliação em andamento é crítica academicamente |
| `adaptive-learning-service` | 1 h | 15 min | Trilha pode operar com fallback estático |
| `integrations-service` | 2 h | 1 h | Sync Moodle e notificação podem atrasar |
| RDS PostgreSQL | 15 min (Multi-AZ failover) | 0 (sync replication) | Núcleo transacional |
| ElastiCache | 30 min (cluster failover) | aceita perda total (cache reconstrói) | Apenas cache |

## Cenários e procedimentos

### Cenário A — Falha de instância única (task Fargate, Lambda)

**Resposta:** automática. Fargate respawna task, Lambda re-tenta. Sem ação humana.

### Cenário B — Falha de AZ inteira

**Resposta:** automática via Multi-AZ.
- ALB redireciona para tasks em AZ saudáveis.
- RDS failover Multi-AZ (~1-2 min).
- Verificação humana: confirmar via dashboard que tasks rebalancearam.

### Cenário C — Falha de região (us-east-1)

**Resposta:** manual, executar plano de DR cross-region.

1. **Pré-condição (já provisionado):** snapshots RDS replicados para `us-west-2` (cross-region snapshot copy, RPO 4h).
2. Restaurar RDS em `us-west-2` a partir do último snapshot:
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --region us-west-2 \
     --db-instance-identifier eduverse-dr \
     --db-snapshot-identifier <latest>
   ```
3. Aplicar Terraform em `us-west-2` apontando para a nova RDS:
   ```bash
   terraform workspace select dr
   terraform apply -var-file=dr.tfvars
   ```
4. Atualizar Route 53 para apontar `api.eduverse.edu.br` para o ALB de `us-west-2`.
5. Validar: smoke test (login + dashboard + submit avaliação).

**RTO esperado:** 2h. **RPO:** até 4h (intervalo de snapshot cross-region).

### Cenário D — Corrupção de dados aplicacional (bug ou ataque)

**Resposta:** Point-in-Time Recovery.

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier eduverse-prod \
  --target-db-instance-identifier eduverse-pitr-restore \
  --restore-time 2026-05-27T14:30:00Z
```

Após restore: comparar com prod, identificar delta, decidir entre rollback total ou cirúrgico.

## Backups

| Recurso | Estratégia | Retenção |
|---|---|---|
| RDS | Automated backup diário + PITR 7 dias | 7 dias automated + 30 dias snapshot manual mensal |
| RDS cross-region | Snapshot copy us-west-2 a cada 4h | 7 dias |
| DynamoDB | Point-in-Time Recovery habilitado | 35 dias |
| Lambda code | Versioning + alias | sempre |
| Terraform state | S3 versionado + DynamoDB lock | sempre |

## Teste de DR

- **Trimestral:** restore de snapshot RDS em ambiente de teste e validação funcional.
- **Semestral:** drill completo de failover cross-region em janela noturna.
- **Resultado de cada drill** registrado em `docs/dr-drills/AAAA-MM-DD.md`.
