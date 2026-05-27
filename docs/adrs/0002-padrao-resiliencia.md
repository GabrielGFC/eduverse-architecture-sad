# ADR 0002 — Padrões de Resiliência

| Campo | Valor |
|---|---|
| ID | ADR-0002 |
| Status | Aceita |
| Data | 2026-05-27 |
| Autor | Gabriel Fernandes Carvalho (2320142) |
| Decisão | Adotar **API Gateway + Circuit Breaker + Bulkhead + Retry com Exponential Backoff**, articulados em camadas |

## Contexto

Com a Fase 3, o EduVerse passa de monolito para **4 microsserviços** (identity, adaptive-learning, assessment, integrations) hospedados em AWS Fargate e Lambda. Microsserviços introduzem **modos de falha distribuídos** inexistentes no monolito: latência variável, timeouts em cadeia, falha parcial de dependências externas (Moodle, motor de IA, serviço de notificação) e contenção de recursos.

A dependência mais crítica é o **motor de recomendação de IA**: histórico operacional mostra picos de latência (p99 > 8 s) e falhas intermitentes. Sem barreiras de resiliência, uma indisponibilidade da IA derrubaria o fluxo síncrono de trilha adaptativa, e potencialmente todo o `adaptive-learning-service` via esgotamento de threads/conexões — o clássico *cascading failure* descrito por Nygard (*Release It!*, 2007).

A decisão precisa cobrir **três camadas** de resiliência: borda, serviço-a-serviço e serviço-a-dependência-externa.

## Decisão

Combinar quatro padrões complementares, cada um na camada onde é mais barato e eficaz:

### Camada 1 — Borda: **API Gateway** (Amazon API Gateway)

- **Função:** ponto único de entrada, terminação TLS, rate limiting por consumidor (aluno/professor/admin), autenticação JWT delegada ao `identity-service`, e WAF.
- **Resiliência entregue:** *throttling* protege os serviços downstream contra *thundering herd* nos picos de avaliação.

### Camada 2 — Serviço a serviço: **Circuit Breaker**

- **Função:** interromper chamadas síncronas para um serviço que está falhando, evitando consumir threads/conexões enquanto o downstream se recupera.
- **Implementação:** biblioteca **Resilience4j** (Java) nos serviços Fargate; no Lambda (Node), **opossum**.
- **Política inicial:** janela de 20 chamadas, abre com ≥ 50% de falhas ou p95 > 2 s, *half-open* após 30 s.

### Camada 3 — Recursos internos: **Bulkhead**

- **Função:** isolar pools de threads/conexões por dependência externa, para que a saturação de uma não consuma os recursos das outras.
- **Aplicação principal:** no `adaptive-learning-service`, pools separados para `RecommendationPort` (IA), `LmsSyncPort` (Moodle) e `ContentRepositoryPort` (Postgres).
- **Implementação:** `Resilience4j Bulkhead` (semáforo) com limite distinto por adapter.

### Camada 4 — Falha transiente: **Retry com Exponential Backoff + Jitter**

- **Função:** absorver falhas transientes de rede e *cold starts* do Lambda.
- **Política:** 3 tentativas, backoff base 200 ms, multiplicador 2, jitter aleatório (Full Jitter, conforme recomendação AWS).
- **Restrição obrigatória:** aplicado **somente em operações idempotentes** (GET, PUT com ID determinístico). Operações de comando passam por mensageria (ver [ADR-0003](0003-modelo-comunicacao.md)).

## Alternativas consideradas

### A. Apenas Retry, sem Circuit Breaker
- ❌ Retry sem breaker **agrava** falhas em massa (retry amplification). Rejeitada — antipadrão documentado em Nygard (2007).

### B. Service Mesh (Istio/AWS App Mesh) para resiliência centralizada
- ✅ Tira a responsabilidade do código de aplicação.
- ❌ Custo operacional do mesh (sidecar Envoy, plano de controle) é desproporcional para 4 serviços. Rejeitada — viável reavaliar quando passar de 10+ serviços.

### C. Timeouts agressivos sem Bulkhead
- ❌ Timeout sozinho não impede *thread starvation* quando muitas requisições estão aguardando o limite. Rejeitada.

### D. Failover ativo-passivo de IA
- ❌ Não há motor de IA secundário; investir em redundância de IA hoje não tem ROI. Mitigação preferida: **fallback degradado** (entregar trilha estática quando o circuit estiver aberto). Rejeitada como padrão primário; **adotada como complemento**.

## Justificativa

Os quatro padrões são **complementares, não substitutos**. O Circuit Breaker protege quando o downstream **está caído**, o Bulkhead protege quando o downstream está **lento** mas vivo, o Retry resolve **falha pontual**, e o API Gateway protege contra **excesso na entrada**. Omitir qualquer um deles deixa uma classe de falha sem cobertura — situação descrita por Nygard como *"stability patterns são um conjunto, não um cardápio"*.

A camada de Bulkhead é especialmente importante no contexto pedagógico do EduVerse: uma indisponibilidade do motor de IA **não pode** impedir um aluno de visualizar progresso ou submeter uma avaliação. O isolamento de pools garante essa propriedade.

Esta decisão também atende diretamente à **ISO/IEC 25010**, na subcaracterística *Fault Tolerance* (parte de *Reliability*), e à característica *Maintainability* (porque encapsula a política de resiliência em bibliotecas reutilizáveis, não dispersa em `try/catch` ad hoc).

## Consequências

**Positivas**
- Falha do motor de IA degrada apenas a recomendação adaptativa; o restante do sistema continua operante (fallback para trilha padrão).
- Picos de avaliação não derrubam o `identity-service` graças ao rate limiting do API Gateway.
- MTTR menor: o breaker volta sozinho via *half-open*, sem intervenção humana.

**Negativas / Trade-offs aceitos**
- Complexidade de configuração das políticas (thresholds, timeouts, tamanhos de pool) — exige tuning baseado em métricas reais, não em chute.
- Necessidade obrigatória de **observabilidade detalhada** (estado do breaker, fila do bulkhead, taxa de retry) — sem isso, as políticas viram caixa-preta.
- Risco de **mascarar bugs**: um sistema resiliente pode esconder problemas reais. Mitigação: alarmes em CloudWatch para *breaker open sustained > 5 min* e *retry rate > 10%*.

## Referências

- NYGARD, M. T. *Release It! Design and Deploy Production-Ready Software*. 2ª ed. Pragmatic Bookshelf, 2018 — capítulos sobre *Stability Patterns* (Circuit Breaker, Bulkhead, Timeouts).
- HOHPE, G.; WOOLF, B. *Enterprise Integration Patterns*. Addison-Wesley, 2003 — padrões de mensageria correlacionados.
- BASS, L.; CLEMENTS, P.; KAZMAN, R. *Software Architecture in Practice*. 3ª ed. Addison-Wesley, 2012 — táticas de *Availability*.
- ISO/IEC 25010:2011 — *Reliability / Fault Tolerance*.
- AWS Architecture Blog — *Exponential Backoff and Jitter* (Brooker, 2015).
