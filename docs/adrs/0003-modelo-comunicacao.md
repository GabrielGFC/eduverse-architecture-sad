# ADR 0003 — Modelo de Comunicação entre Serviços

| Campo | Valor |
|---|---|
| ID | ADR-0003 |
| Status | Aceita |
| Data | 2026-05-27 |
| Autor | Gabriel Fernandes Carvalho (2320142) |
| Decisão | Adotar **híbrido**: REST/HTTPS síncrono para *query* interativa; **mensageria assíncrona** (EventBridge + SQS) para *commands* de longo prazo e integração externa |

## Contexto

A decomposição da Fase 3 (4 microsserviços + 4 dependências externas) força uma escolha explícita do **modelo de comunicação** entre serviços. A escolha errada cria os dois piores antipadrões de microsserviços:

1. **Síncrono em excesso** → *distributed monolith*: cada request do usuário aciona uma cadeia de chamadas HTTP; uma falha derruba a cadeia inteira e a latência soma.
2. **Assíncrono em excesso** → consistência eventual em fluxos que o usuário espera ver imediatamente; complexidade desproporcional para um GET simples.

Os fluxos do EduVerse não são homogêneos:

| Fluxo | Característica | Quem espera |
|---|---|---|
| Aluno abre dashboard | Leitura, latência < 500 ms | Usuário humano em tela |
| Submissão de avaliação | Comando, precisa de ACK | Usuário em tela |
| Geração de recomendação por IA | Comando lento (segundos) | Pode ser eventual |
| Sincronização com Moodle | Batch, tolerante a atraso | Sistema |
| Disparo de notificação | Fire-and-forget | Sistema |

Tratar todos esses fluxos com o mesmo protocolo é precisamente o que Hohpe & Woolf (2003) descrevem como o erro mais comum de integração corporativa.

## Decisão

**Híbrido orientado ao perfil do fluxo:**

### Comunicação síncrona — REST/HTTPS sobre HTTP/2

- **Uso:** *queries* que alimentam diretamente a interface do usuário (dashboard, listagem de trilha, consulta de progresso).
- **Quem:** Portal Web → API Gateway → serviço; e chamadas serviço-a-serviço **apenas** quando o consumidor precisa do resultado para responder ao usuário.
- **Contrato:** OpenAPI 3.1 versionado, gerado a partir do código (single source of truth no domínio).
- **Resiliência:** governada pelo [ADR-0002](0002-padrao-resiliencia.md) (Circuit Breaker + Bulkhead + Retry).

### Comunicação assíncrona — **EventBridge** (eventos de domínio) + **SQS** (commands point-to-point)

- **Uso:** comandos de longa duração, sincronização externa, notificações, e qualquer fluxo onde "feito eventualmente" é suficiente.
- **Padrão:** **eventos de domínio** publicados em EventBridge, consumidos por quem se interessar (pub/sub desacoplado). Commands diretos (ex.: `EnqueueRecommendationJob`) usam SQS para garantir entrega exatamente-uma-vez com dedup.
- **Garantias:** *at-least-once delivery* + consumidores idempotentes (dedup por `eventId` em tabela de outbox).
- **Esquema:** **CloudEvents 1.0** como envelope padrão; payload versionado por schema registry.

### Mapeamento dos fluxos

| Fluxo | Protocolo | Justificativa |
|---|---|---|
| `GET /aluno/{id}/dashboard` | REST síncrono | UI bloqueia até retorno |
| `POST /assessment/{id}/submit` | REST síncrono (ACK) + evento `AssessmentSubmitted` | Aluno precisa ver "enviado"; correção pode ser assíncrona |
| Geração de recomendação | Assíncrono (evento `LearningProgressUpdated` → Lambda) | Latência da IA é variável (até 8 s) |
| Sync Moodle | Assíncrono (SQS + Lambda batch) | Janela noturna, tolerante a falha |
| Notificação push/email | Assíncrono (evento → `integrations-service`) | Fire-and-forget |

## Alternativas consideradas

### A. Tudo síncrono via REST
- ✅ Simples, familiar, ferramentas maduras.
- ❌ Acopla **disponibilidade temporal**: se a IA está fora, a submissão de avaliação trava. Recria o monolito distribuído. Rejeitada — viola o princípio de *temporal decoupling* dos microsserviços (Newman, *Building Microservices*, 2ª ed., 2021).

### B. Tudo assíncrono via mensageria
- ✅ Desacoplamento máximo, resiliência intrínseca.
- ❌ GETs simples viram polling ou WebSocket — complexidade desnecessária. UX degrada (usuário não vê resultado imediato). Rejeitada por **inadequação à interação humana**.

### C. gRPC para comunicação interna
- ✅ Performance superior ao REST, contratos fortes via protobuf.
- ❌ Curva de adoção, ferramental do time é REST/JSON, e ganho de latência é marginal frente ao já estabelecido pelo API Gateway. Rejeitada por **custo de adoção > benefício atual**; reavaliar quando houver gargalo medido.

### D. Choreography pura via eventos (sem orquestração)
- ✅ Máximo desacoplamento.
- ❌ Fluxos com múltiplos passos (ex.: matrícula → trilha → primeira recomendação) ficam difíceis de rastrear e debugar. Rejeitada — preferência por **orquestração leve via SQS/Step Functions** onde houver workflow multi-etapas; eventos onde houver fan-out.

### E. Kafka self-managed
- ✅ Throughput e ordering forte.
- ❌ Operar Kafka exige time dedicado; EventBridge + SQS atende o volume previsto sem essa carga. Rejeitada por **complexidade operacional**.

## Trade-offs explícitos

| Dimensão | Síncrono (REST) | Assíncrono (EventBridge/SQS) |
|---|---|---|
| Latência percebida | Baixa, previsível | Variável, eventualmente consistente |
| Acoplamento temporal | Alto (downstream precisa estar UP) | Baixo (broker absorve indisponibilidade) |
| Complexidade de debug | Baixa (cadeia linear, fácil de rastrear) | Alta (precisa de tracing distribuído) |
| Garantia de entrega | At-most-once por natureza | At-least-once com dedup obrigatório |
| Adequação à UX humana | Excelente | Ruim para confirmação imediata |
| Adequação a falha parcial | Frágil sem ADR-0002 | Resiliente por design |

A decisão híbrida aceita **conscientemente** a complexidade extra do debug assíncrono em troca de desacoplamento temporal nos fluxos certos. Essa complexidade é mitigada pelo tracing X-Ray (ADR-0001) e pelo *correlation ID* propagado no envelope CloudEvents.

## Justificativa

O modelo híbrido espelha o **perfil real de cada interação**, evitando tanto o monolito distribuído quanto o overengineering assíncrono. Esta abordagem é consistente com:

- **Hohpe & Woolf (2003)** — escolha do estilo de integração deve seguir as propriedades do dado e do fluxo, não preferência de plataforma.
- **Newman (2021)** — *temporal decoupling* como propriedade fundamental de microsserviços bem desenhados, mas obtido seletivamente.
- **ISO/IEC 25010** — atende *Reliability* (assíncrono absorve falha) sem sacrificar *Usability* (síncrono onde o usuário espera resposta).
- **Clean Architecture (Martin, 2017)** — o domínio publica *eventos de negócio* (não mensagens de transporte); a escolha do canal é detalhe de infraestrutura escondido por *adapters*, mantendo a Regra de Dependência.

## Consequências

**Positivas**
- Falha do motor de IA não bloqueia submissão de avaliação.
- Picos de sincronização Moodle não competem por threads com tráfego de usuário.
- Evolução incremental: novos consumidores assinam eventos existentes sem mexer no publisher.

**Negativas / Trade-offs aceitos**
- **Consistência eventual** em fluxos assíncronos exige UI que comunique status ("recomendação sendo gerada"), não silêncio.
- **Padrão Outbox** obrigatório no `adaptive-learning-service` para garantir atomicidade entre persistência e publicação do evento — adiciona complexidade no repositório.
- **Schema evolution**: contratos de evento são tão críticos quanto contratos REST; exigem versionamento e schema registry.
- **Observabilidade obrigatória**: sem correlation ID propagado e tracing, debug de fluxo assíncrono é inviável.

## Referências

- HOHPE, G.; WOOLF, B. *Enterprise Integration Patterns*. Addison-Wesley, 2003 — padrões *Message Channel*, *Publish-Subscribe*, *Idempotent Receiver*.
- NEWMAN, S. *Building Microservices*. 2ª ed. O'Reilly, 2021 — cap. 4 (*Styles of Microservice Communication*).
- FOWLER, M. *Patterns of Enterprise Application Architecture*. Addison-Wesley, 2002 — *Transactional Outbox*.
- MARTIN, R. C. *Clean Architecture*. Prentice Hall, 2017 — Regra de Dependência aplicada a *messaging adapters*.
- ISO/IEC 25010:2011 — *Reliability* e *Compatibility / Interoperability*.
- CloudEvents 1.0 Specification — CNCF.
