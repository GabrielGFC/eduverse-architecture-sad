# ADR 0001 — Estratégia de Nuvem e Escalabilidade

| Campo | Valor |
|---|---|
| ID | ADR-0001 |
| Status | Aceita |
| Data | 2026-05-27 |
| Autor | Gabriel Fernandes Carvalho (2320142) |
| Decisão | Adotar **AWS em modelo híbrido PaaS + Serverless**, com escalabilidade **horizontal** orientada a demanda |

## Contexto

A Fase 3 do EduVerse exige evolução do monolito modular hexagonal (decidido no [ADR-002](ADR-002-arquitetura-hexagonal.md)) para um cenário **cloud-native baseado em microsserviços**. O sistema atende três classes de carga muito distintas:

1. **Carga interativa contínua** — alunos e professores acessando trilhas e dashboards (latência sensível, picos diários).
2. **Carga acadêmica em rajada** — janelas de avaliação, sincronização com Moodle e fechamento de bimestre (picos previsíveis, 10–30× a média).
3. **Carga assíncrona pedagógica** — recomputo de recomendações de IA, sincronização batch com LMS e disparos de notificação (event-driven, tolerante a latência).

Misturar essas três classes na mesma topologia de infraestrutura desperdiça recurso na 1, falha na 2 e onera a 3. A decisão precisa cobrir simultaneamente **modelo de serviço de nuvem**, **estratégia de escalabilidade** e **provedor**.

## Decisão

Adotar a **AWS** como provedor único, em arquitetura híbrida:

| Componente EduVerse | Serviço AWS | Modelo | Justificativa |
|---|---|---|---|
| `identity-service`, `adaptive-learning-service`, `assessment-service` | **ECS Fargate** (containers gerenciados) | PaaS | Cargas interativas com latência previsível; autoscaling horizontal por CPU/RPS. |
| `integrations-service` (LMS, IA, notificação) | **AWS Lambda** + **EventBridge** + **SQS** | Serverless | Cargas event-driven, com picos imprevisíveis e ociosidade longa — paga-se por execução. |
| Banco transacional | **Amazon RDS PostgreSQL Multi-AZ** | PaaS gerenciado | Mantém o stack do monolito; failover automático; read replicas para dashboards. |
| Cache | **Amazon ElastiCache (Redis)** | PaaS gerenciado | Continuidade com o cache de recomendações já previsto no C4. |
| Edge | **CloudFront + API Gateway** | PaaS | Termina TLS, aplica WAF e roteia para Fargate/Lambda. |
| Observabilidade | **CloudWatch + X-Ray** | PaaS | Tracing distribuído nativo entre Fargate e Lambda. |

**Escalabilidade:** **horizontal por padrão**, via *Application Auto Scaling* nos serviços ECS (alvo de 60% CPU e 70% memória) e concorrência reservada no Lambda. Escalabilidade vertical é reservada apenas ao RDS (instância e storage), porque banco relacional não horizontaliza graciosamente sem sharding — o que seria custo desproporcional ao volume atual.

## Alternativas consideradas

### 1. IaaS puro (EC2 + Auto Scaling Groups)
- ✅ Custo unitário menor de CPU/RAM em uso constante; controle total.
- ❌ A equipe assume patching, AMIs, hardening, instalação de runtime e orquestração — custo operacional desproporcional ao tamanho do time. Rejeitada por **overhead operacional**.

### 2. SaaS-only (ex.: backend-as-a-service tipo Supabase/Firebase)
- ✅ Time-to-market mínimo.
- ❌ EduVerse tem **dependência forte de integração com Moodle e motor de IA proprietário**, o que ultrapassa o limite do que um BaaS oferece sem ginástica. Lock-in alto em camada de negócio. Rejeitada por **inadequação ao domínio**.

### 3. Kubernetes (EKS) puro
- ✅ Portabilidade máxima; padrão de mercado para microsserviços.
- ❌ Custo operacional (control plane, ingress, observabilidade, autoscaler) é alto para 4 serviços. Fargate entrega o mesmo modelo de container com 1/3 do overhead operacional. Rejeitada por **complexidade desproporcional ao estágio**.

### 4. Serverless puro (tudo em Lambda)
- ✅ Custo zero em ociosidade.
- ❌ Cargas interativas síncronas sofrem com **cold start** e com o limite de 15 min por execução. Inadequado para o backend pedagógico contínuo. Rejeitada por **perfil de carga**.

### 5. Escalabilidade vertical como estratégia primária
- ✅ Simples de operar.
- ❌ Pressman (2011, cap. 9) e Bass, Clements & Kazman (*Software Architecture in Practice*, 3ª ed.) reforçam que **escalabilidade vertical possui teto físico e indisponibilidade durante o resize**. Não atende o pico de avaliações. Rejeitada por **risco de disponibilidade**.

## Justificativa

A escolha por **híbrido PaaS + Serverless** mapeia 1-para-1 o **perfil de carga real** do EduVerse: serviços interativos em containers (Fargate) onde latência manda, e integrações reativas em Lambda onde o custo de ociosidade manda. Essa separação atende dois atributos de qualidade da **ISO/IEC 25010**: *Performance Efficiency* (resource utilization e capacity) e *Reliability* (availability via Multi-AZ + retry de SQS).

A **escalabilidade horizontal** é coerente com a Regra de Dependência da Clean Architecture (Martin, 2017): como o domínio não conhece a infraestrutura, replicar instâncias do mesmo container não introduz acoplamento novo — apenas eleva throughput. O ADR-0003 detalha o impacto da escolha horizontal sobre o modelo de comunicação (preferência por mensageria).

A opção pela AWS, em vez de Azure, decorre de três pontos pragmáticos: maturidade do par Fargate+Lambda, integração nativa com EventBridge para o ADR-0003, e disponibilidade de créditos AWS Educate para o contexto acadêmico do projeto.

## Consequências

**Positivas**
- Capacidade de absorver picos de 10–30× sem provisionamento manual.
- Time da equipe foca em domínio, não em sysadmin (alinhado ao princípio do monolito modular hexagonal já estabelecido).
- Custo proporcional ao uso real do `integrations-service` (Lambda paga por execução).
- Failover automático no RDS Multi-AZ reduz RTO para minutos.

**Negativas / Trade-offs aceitos**
- **Lock-in moderado na AWS**: portabilidade exigirá reempacotamento dos Lambdas. Mitigado mantendo o domínio livre de SDK AWS (adapters concentram a dependência).
- **Custo de cold start no Lambda**: aceitável porque o `integrations-service` é assíncrono.
- **Necessidade de observabilidade distribuída**: tracing X-Ray passa a ser obrigatório desde o dia 1 (não opcional como no monolito).
- **Curva de aprendizado** em IaC (Terraform) para reproduzir o ambiente.

## Referências

- BASS, L.; CLEMENTS, P.; KAZMAN, R. *Software Architecture in Practice*. 3ª ed. Addison-Wesley, 2012 — capítulos sobre *Performance* e *Availability* como atributos de qualidade.
- PRESSMAN, R. S. *Engenharia de Software: Uma Abordagem Profissional*. 7ª ed. AMGH, 2011 — cap. 9 (Modelagem de Projeto Arquitetural).
- MARTIN, R. C. *Clean Architecture*. Prentice Hall, 2017 — Regra de Dependência.
- ISO/IEC 25010:2011 — *Performance Efficiency* e *Reliability*.
- AWS Well-Architected Framework — pilares *Reliability* e *Cost Optimization*.
