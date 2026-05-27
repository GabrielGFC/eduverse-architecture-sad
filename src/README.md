# `src/` — Microsserviços do EduVerse (Fase 3)

Esta pasta concentra o **scaffolding** dos 4 microsserviços definidos no [SAD Fase 3](../docs/sad/sad-fase3.md). O código de produção será preenchido seguindo o roadmap incremental descrito no SAD (seção 10).

## Estrutura de cada serviço

Cada microsserviço preserva **internamente** a Arquitetura Hexagonal validada na Fase 2 ([ADR-002](../docs/adrs/ADR-002-arquitetura-hexagonal.md)):

```text
<service-name>/
├── README.md
├── pom.xml | package.json
└── src/
    ├── main/
    │   ├── domain/            # Entities + Use Cases (independente de framework)
    │   ├── application/       # Driving Ports + orquestração
    │   ├── infrastructure/    # Adapters (REST, persistência, mensageria)
    │   └── config/            # Spring/Lambda boot
    └── test/
        ├── unit/              # domínio puro
        ├── integration/       # adapters reais (Testcontainers)
        └── contract/          # Pact / OpenAPI contract tests
```

## Mapa de serviços

| Serviço | Runtime | Responsabilidade | Persistência |
|---|---|---|---|
| [`identity-service`](identity-service/) | Java 21 + Spring Boot 3 (Fargate) | Autenticação JWT, RBAC | RDS PG (`identity`) |
| [`adaptive-learning-service`](adaptive-learning-service/) | Java 21 + Spring Boot 3 (Fargate) | Trilhas adaptativas, recomendações | RDS PG (`learning`) + ElastiCache |
| [`assessment-service`](assessment-service/) | Java 21 + Spring Boot 3 (Fargate) | Avaliações e correção | RDS PG (`assessment`) |
| [`integrations-service`](integrations-service/) | Node 20 + TypeScript (Lambda) | Adapters Moodle/IA/Notificação/Conteúdo | DynamoDB (estado de jobs) |

## Comunicação entre serviços

Conforme [ADR-0003](../docs/adrs/0003-modelo-comunicacao.md):

- **Síncrono:** REST/HTTPS via API Gateway, contratos OpenAPI 3.1.
- **Assíncrono:** eventos de domínio em **EventBridge**, comandos em **SQS**, envelope **CloudEvents 1.0**.

## Resiliência

Conforme [ADR-0002](../docs/adrs/0002-padrao-resiliencia.md):

- Java: **Resilience4j** (CircuitBreaker, Bulkhead, Retry, TimeLimiter).
- Node: **opossum** (CircuitBreaker) + retry nativo do SDK AWS com jitter.

## Próximos passos (scaffolding)

1. Adicionar `pom.xml` / `package.json` em cada serviço.
2. Definir contratos OpenAPI iniciais em cada `README` de serviço.
3. Criar `docker-compose.dev.yml` na raiz desta pasta para subir Postgres + Redis + LocalStack.
