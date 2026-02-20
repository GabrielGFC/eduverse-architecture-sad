# Documento de Visão Arquitetural – EduVerse

---
**Aluno:** Gabriel Fernandes de Carvalho |    **Matricula:** 2320142

**Link do Repositorio:** https://github.com/gabrielgfc1/eduverse-architecture-sad

---

## CICLO 1: Visao e Requisitos (Fase 1)

### 1.1 Resumo do Cenario de Negocio

O EduVerse endereça um problema recorrente no ensino digital: a padronizacao excessiva
das trilhas de aprendizado, que ignora o ritmo e o perfil cognitivo individual de cada
aluno, contribuindo para baixo engajamento e altas taxas de evasao. Utilizando
inteligencia artificial, a plataforma constroi percursos personalizados e entrega
feedback automatizado em tempo real, atuando como uma camada adaptativa sobre a
infraestrutura educacional ja existente nas instituicoes. Os usuarios principais sao
alunos, que consomem as trilhas personalizadas; professores, que supervisionam e
realizam a curadoria do conteudo pedagogico; e gestores academicos, que monitoram
indicadores de desempenho e retencao. A solucao integra-se a LMS institucionais,
repositorios de conteudo e servicos de autenticacao externos, entregando valor
mensuravel: maior retencao estudantil, melhoria de desempenho academico e reducao da
carga operacional docente via automacao pedagogica.

---

### 1.2 Atributos de Qualidade (RNFs) Priorizados

1. **Escalabilidade:** O volume de usuarios simultaneos varia drasticamente em periodos
   de pico — inicio de semestre e ciclos avaliativos — exigindo que a arquitetura suporte
   crescimento horizontal sem degradacao de servico. Isso orienta decisoes como autoscaling
   em nuvem, particionamento por tenant e uso de microsservicos desacoplados.

2. **Disponibilidade:** Interrupcoes na plataforma impactam diretamente avaliacoes em
   andamento e a continuidade das trilhas adaptativas, comprometendo a confianca
   institucional. A arquitetura deve prever redundancia de instancias, failover automatizado
   e SLA com uptime minimo de 99,9%.

3. **Adaptabilidade (Manutenibilidade):** Os modelos de IA e as regras pedagogicas
   evoluem continuamente, exigindo que componentes como o motor de recomendacao possam ser
   substituidos ou atualizados de forma independente. Isso impoe baixo acoplamento entre
   modulos e interfaces bem definidas entre camadas.

4. **Seguranca:** A plataforma processa dados sensiveis de estudantes, sujeitos a LGPD e,
   em contextos internacionais, a FERPA. Arquiteturalmente, isso requer autenticacao
   federada, controle de acesso baseado em papeis (RBAC), criptografia em transito e em
   repouso, alem de trilhas de auditoria para rastreabilidade de acoes.

5. **Desempenho (Tempo de Resposta):** A proposta de valor adaptativa depende de
   recomendacoes e feedbacks entregues em tempo proximo ao real — latencias elevadas quebram
   o fluxo de aprendizado e reduzem o engajamento. Isso exige caching inteligente,
   processamento assíncrono para operacoes pesadas e otimizacao das consultas ao modelo de
   IA.

---

### 1.3 Diagrama de Contexto (C4 Nivel 1)

[Insira aqui a imagem do seu Diagrama de Contexto (C4 Nivel 1). Este diagrama deve
mostrar o sistema como uma caixa preta e suas interacoes com usuarios e outros sistemas
externos. Recomendado: Salvar o diagrama em `/diagrams` no GitHub e referenciar o link
da imagem aqui.]

---

### 1.4 Classificacao da Estrategia

- **Classificacao:** [Conservadora / Balanceada / Ousada]
- **Justificativa:** [Explique em 5 linhas o porque desta escolha em relacao ao risco,
  inovacao e maturidade tecnologica. Referencie o Capitulo 1 do Pressman sobre a natureza
  do software, se pertinente.]

---

## CICLO 2: Blueprint e Decisoes (Fase 2)

*Preencher e entregar no AVA ao final do Ciclo 2.*

### 2.1 Diagrama de Containers (C4 Nivel 2)

[Insira aqui a imagem do seu Diagrama de Containers (C4 Nivel 2). Este diagrama deve
detalhar a estrutura interna do sistema, mostrando os principais containers (aplicacoes,
bancos de dados, filas, etc.) e suas interacoes. Recomendado: Salvar o diagrama em
`/diagrams` no GitHub e referenciar o link da imagem aqui.]

---

### 2.2 Estilo Arquitetural Escolhido

[Descreva o estilo arquitetural principal que voce adotou (ex: Microsservicos, Monolito
Modular, Hexagonal, Event-Driven) e justifique sua escolha com pelo menos 3 trade-offs
reais (pros e contras) em relacao aos RNFs priorizados na Fase 1. Referencie o Capitulo
14 do Pressman sobre estilos arquiteturais, se pertinente.]

---

### 2.3 Architecture Decision Record (ADR) Principal

[Escolha uma decisao arquitetural crucial que voce tomou nesta fase e documente-a como
um ADR. Recomendado: Criar o arquivo `.md` do ADR em `/adrs` no GitHub e referenciar o
link aqui.]

- **Titulo:** [Ex: Escolha da Tecnologia de Persistencia]
- **Contexto:** [O problema ou necessidade tecnica que levou a essa decisao.]
- **Decisao:** [O que foi decidido. Qual tecnologia/abordagem foi escolhida?]
- **Justificativa:** [Por que esta opcao venceu as alternativas? Quais foram os
  trade-offs considerados? Quais os impactos nos RNFs?]

---

## CICLO 3: Cloud e Resiliencia (Fase 3)

*Preencher e entregar no AVA ao final do Ciclo 3.*

### 3.1 Estrategia de Cloud e Implantacao

[Descreva como sua arquitetura sera implantada em um ambiente de nuvem (ex: AWS, Azure,
GCP). Qual o modelo de servico (IaaS, PaaS, Serverless)? Como o sistema sera escalado e
monitorado?]

---

### 3.2 Analise de Fragilidade e Mitigacao

- **Ponto Fragil:** [Identifique a maior fraqueza ou risco da sua arquitetura em um
  cenario de producao (ex: falha de um servico critico, pico de trafego inesperado,
  vulnerabilidade de seguranca).]
- **Mitigacao:** [Como voce minimizaria esse risco? Quais estrategias de resiliencia
  (ex: circuit breaker, retry, fallback, multi-regiao) seriam aplicadas?]

---

### 3.3 Parecer Tecnico Final

[Resumo executivo (ate 10 linhas) defendendo por que sua arquitetura e a melhor escolha
para o cliente, considerando os requisitos de negocio, os RNFs e a estrategia de
implantacao. Qual o valor agregado da sua solucao?]

---

## BONUS: Evolucao Arquitetural (Gamificacao)

*Opcional — Preencher apenas se houver melhoria estrutural documentada no GitHub.*

[Descreva brevemente a melhoria arquitetural que voce implementou no seu repositorio
GitHub para fins de bonus de nota. Referencie a nova ADR e o diagrama atualizado (se
houver) no GitHub. Ex: Migracao de um componente para Serverless, implementacao de um
padrao de resiliencia, otimizacao de custo em cloud. Lembre-se: a melhoria deve ser
arquitetural, nao apenas textual.]

---

## Referencias Bibliograficas

- **Pressman, R. S.** (2021). *Engenharia de Software: Uma Abordagem Profissional*.
  McGraw Hill. (Capitulos selecionados conforme o tema da aula).
- **Richards, M., & Ford, N.** (2020). *Fundamentals of Software Architecture: An
  Engineering Approach*. O'Reilly Media.
- **C4 Model for Software Architecture.** (s.d.). Disponivel em:
  [https://c4model.com/](https://c4model.com/)
- **Architecture Decision Records (ADRs).** (s.d.). Disponivel em:
  [https://adr.github.io/](https://adr.github.io/)