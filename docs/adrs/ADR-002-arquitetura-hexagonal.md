# ADR-002 - Adocao da Arquitetura Hexagonal no EduVerse

| Campo | Valor |
| --- | --- |
| ID | ADR-002 |
| Status | Aceita |
| Data | 2026-04-10 |
| Decisao | Isolar o dominio pedagogico por meio de Ports & Adapters |

## Contexto

O EduVerse precisa coexistir com o LMS institucional da instituicao, integrar um motor de recomendacao, consultar um repositorio de conteudo e disparar notificacoes sem transformar essas dependencias externas em parte do nucleo de negocio. O risco principal identificado na analise da Fase 1 foi o acoplamento entre regras pedagogicas e detalhes de infraestrutura, problema tipico de organizacoes N-Tier mal saneadas.

Se esse acoplamento permanecer, qualquer alteracao em Moodle, banco de dados, framework web ou servico de IA passa a gerar impacto direto em entidades, casos de uso e testes. Isso aumenta a divida tecnica e reduz a capacidade de evolucao da plataforma.

## Decisao

Adotar **Arquitetura Hexagonal (Ports & Adapters)** como estilo principal de organizacao do backend do EduVerse, complementada por principios de **Clean Architecture** para garantir que as dependencias de codigo apontem para dentro.

O backend passa a ser estruturado em torno de:

- **Entities**: conceitos pedagogicos centrais, como aluno, trilha adaptativa, progresso e avaliacao
- **Use Cases**: orquestracao de recomendacoes, avaliacao, acompanhamento e sincronizacao
- **Driven Ports**: contratos que o dominio define para falar com LMS, IA, notificacao e persistencia
- **Adapters**: implementacoes concretas desses contratos na infraestrutura

## Alternativas consideradas

### 1. Manter N-Tier com acoplamento direto

**Vantagens**

- menor curva inicial de implementacao
- organizacao familiar para CRUDs simples

**Desvantagens**

- dominio contaminado por ORM, framework e banco
- maior custo de manutencao e teste
- baixa flexibilidade para coexistencia e troca futura do LMS

### 2. Adotar microsservicos distribuidos desde o inicio

**Vantagens**

- escalabilidade fisica mais agressiva
- isolamento operacional entre partes do sistema

**Desvantagens**

- maior custo financeiro e operacional
- necessidade de observabilidade distribuida, deploy independente e orquestracao
- complexidade desproporcional ao estagio atual do projeto

### 3. Adotar monolito modular com Arquitetura Hexagonal

**Vantagens**

- isolamento do dominio sem assumir custo precoce de distribuicao
- boa testabilidade com adaptadores falsos
- evolucao controlada de integracoes e da camada pedagogica

**Desvantagens**

- exige disciplina para preservar fronteiras arquiteturais
- adiciona abstracoes que nao existem em uma implementacao CRUD direta

## Justificativa

A opcao escolhida equilibra risco, custo e valor de negocio. Conforme Pressman (2011), a arquitetura e o primeiro ponto em que a qualidade do software pode ser avaliada. Ja Martin (2017) reforca que dependencias devem apontar para dentro. No EduVerse, isso e especialmente importante porque a plataforma so faz sentido se conseguir conviver com o Moodle e com servicos externos sem perder controle sobre seu dominio pedagogico.

Essa decisao tambem e coerente com a classificacao estrategica **Balanceada**: o projeto inova na camada adaptativa, mas evita substituir imediatamente o ecossistema institucional e evita antecipar a complexidade operacional de microsservicos.

## Ports & Adapters previstos

| Tipo | Contrato | Responsabilidade | Implementacao inicial |
| --- | --- | --- | --- |
| Driven Port | `LmsSyncPort` | Sincronizar turmas, matriculas e progresso com Moodle | `MoodleAdapter` |
| Driven Port | `RecommendationPort` | Solicitar recomendacoes ao motor de IA | `AiRecommendationAdapter` |
| Driven Port | `ContentRepositoryPort` | Obter e persistir materiais de apoio | `PostgresContentAdapter` |
| Driven Port | `NotificationPort` | Enviar lembretes e alertas | `NotificationAdapter` |
| Driving Port | `AdaptiveLearningUseCase` | Executar a trilha adaptativa | Controllers e jobs internos |
| Driving Port | `AssessmentUseCase` | Aplicar e corrigir avaliacoes | Controllers e jobs internos |
| Driving Port | `ProgressTrackingUseCase` | Acompanhar progresso academico | Controllers e dashboards |

## Consequencias

- o dominio pode ser testado sem banco de dados, LMS ou motor de IA reais
- a troca do LMS institucional no futuro nao exige reescrita do nucleo pedagogico
- o sistema preserva capacidade de evolucao para cloud e distribuicao posterior
- a equipe precisa sustentar explicitamente os limites entre dominio e infraestrutura

## Referencias

- COCKBURN, Alistair. *Hexagonal Architecture*. 2005.
- MARTIN, Robert C. *Clean Architecture*. Prentice Hall, 2017.
- PRESSMAN, Roger S. *Engenharia de Software: Uma Abordagem Profissional*. 7a ed. AMGH, 2011.
