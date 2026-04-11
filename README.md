# EduVerse - Mini Projeto de Arquitetura de Software

Repositorio final de entrega do mini projeto "O Arquiteto Decisor" para o cenario **EduVerse**.

Este repositorio contem apenas os artefatos curados da entrega academica. Os materiais brutos de aula, PDFs do professor, referencias auxiliares e configuracoes locais de ferramentas ficam separados no repositorio-fonte `tarefa-carlos`.

## Objetivo

O EduVerse e uma plataforma de aprendizado adaptativo que opera como camada complementar ao LMS institucional. A proposta central e personalizar trilhas de estudo, recomendacoes e feedbacks sem substituir imediatamente o ambiente academico ja adotado pela instituicao.

No contexto deste mini projeto, a entrega foi organizada para demonstrar:

- correcao do Ciclo 1 com base no feedback do professor
- definicao arquitetural do Ciclo 2 com justificativas, trade-offs e ADR
- preparacao do Ciclo 3 como roadmap de cloud e resiliencia

## Estrutura do repositorio

```text
eduverse-architecture-sad/
|-- README.md
|-- docs/
|   `-- mini-projeto-eduverse-2320142.md
|-- adrs/
|   `-- ADR-002-arquitetura-hexagonal.md
`-- diagrams/
    |-- c4-contexto-eduverse.mmd
    |-- c4-contexto-eduverse.png
    |-- c4-containers-eduverse.mmd
    |-- c4-containers-eduverse.png
    |-- ports-adapters-eduverse.mmd
    `-- ports-adapters-eduverse.png
```

## Artefatos principais

- Documento principal: [`docs/mini-projeto-eduverse-2320142.md`](docs/mini-projeto-eduverse-2320142.md)
- ADR principal: [`adrs/ADR-002-arquitetura-hexagonal.md`](adrs/ADR-002-arquitetura-hexagonal.md)
- Diagrama C4 Nivel 1: [`diagrams/c4-contexto-eduverse.png`](diagrams/c4-contexto-eduverse.png)
- Diagrama C4 Nivel 2: [`diagrams/c4-containers-eduverse.png`](diagrams/c4-containers-eduverse.png)
- Mapa de Ports & Adapters: [`diagrams/ports-adapters-eduverse.png`](diagrams/ports-adapters-eduverse.png)

## Decisao arquitetural central

O backend do EduVerse foi definido como um **monolito modular organizado com Arquitetura Hexagonal e principios de Clean Architecture**. Essa decisao protege o dominio pedagogico contra acoplamento com banco de dados, LMS, motor de IA e servicos de notificacao, ao mesmo tempo em que evita o custo operacional de microsservicos distribuidos logo no inicio.

Essa escolha atende ao feedback da disciplina e reforca quatro pontos centrais:

- coexistencia explicita com Moodle como restricao de negocio
- isolamento do dominio conforme a Regra de Dependencia de Martin
- estrategia **Balanceada**, coerente com o risco e com a maturidade do contexto
- discussao clara entre custo financeiro, desempenho e manutenibilidade

## Escopo do documento principal

O arquivo principal em Markdown foi organizado assim:

- **Ciclo 1 corrigido**: resumo do cenario, RNFs conectados ao contexto educacional, C4 Nivel 1 e classificacao estrategica revisada
- **Ciclo 2 completo**: C4 Nivel 2, estilo arquitetural, saneamento do modelo anterior, ADR e analise de trade-offs
- **Ciclo 3 como roadmap**: direcionamento futuro de cloud e resiliencia, sem apresentar essa fase como concluida

## Conversao para PDF

O formato principal de autoria deste repositorio e Markdown. A versao em PDF deve ser gerada a partir do arquivo [`docs/mini-projeto-eduverse-2320142.md`](docs/mini-projeto-eduverse-2320142.md) quando a entrega final for consolidada.

## Referencias de base

- PRESSMAN, Roger S. *Engenharia de Software: Uma Abordagem Profissional*. 7a ed. AMGH, 2011.
- MARTIN, Robert C. *Clean Architecture*. Prentice Hall, 2017.
- COCKBURN, Alistair. *Hexagonal Architecture*, 2005.
- C4 Model. [https://c4model.com/](https://c4model.com/)
