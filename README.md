# EduVerse — Mini Projeto de Arquitetura de Software

![Status](https://img.shields.io/badge/status-em%20andamento-yellow)
![Ciclo](https://img.shields.io/badge/ciclo-1%20de%203-blue)
![Licenca](https://img.shields.io/badge/licen%C3%A7a-MIT-green)
![Disciplina](https://img.shields.io/badge/disciplina-Arquitetura%20de%20Software-blueviolet)

> Repositorio de documentacao arquitetural do projeto EduVerse, desenvolvido como parte
> do Mini Projeto "O Arquiteto Decisor" — atividade avaliativa da disciplina de
> Arquitetura de Software.

---

## Sobre o Projeto

O **EduVerse** e uma plataforma de aprendizado adaptativo que utiliza inteligencia
artificial para construir trilhas de ensino personalizadas e entregar feedback
automatizado em tempo real. O objetivo e reduzir a evasao escolar e melhorar o
desempenho academico por meio da personalizacao do ensino em escala.

Este repositorio nao contem codigo de producao — ele documenta as decisoes arquiteturais,
diagramas e justificativas tecnicas produzidas ao longo dos tres ciclos do projeto.

---

## Contexto Arquitetural

Sistemas educacionais digitais sofrem evolucao continua devido a mudancas pedagogicas,
tecnologicas e regulatórias. Conforme discutido na Engenharia de Software (Pressman),
o software nao se desgasta fisicamente, mas deteriora quando mudancas sao introduzidas
sem controle arquitetural.

Dessa forma, o EduVerse foi concebido com foco em evolucao sustentavel,
modularidade e rastreabilidade de decisoes tecnicas, evitando debito tecnico estrutural
e permitindo crescimento controlado da plataforma ao longo do tempo.

---

## Principios Arquiteturais

A arquitetura do EduVerse segue os seguintes principios:

- Evolucao continua: o sistema deve permitir mudancas sem impacto sistêmico elevado  
- Modularidade: componentes desacoplados para facilitar manutencao e expansao  
- Escalabilidade horizontal: suporte ao crescimento de usuarios e dados educacionais  
- Rastreabilidade: decisoes arquiteturais documentadas via ADRs  
- Integracao por APIs: interoperabilidade com sistemas academicos existentes  

---

## Relacao com os 4Ps da Engenharia de Software

A definicao arquitetural do EduVerse considera o equilibrio entre os 4Ps:

- **Pessoas:** arquitetura pensada para times multidisciplinares de educacao e tecnologia  
- **Produto:** foco em personalizacao, escalabilidade e experiencia do usuario  
- **Processo:** governanca tecnica baseada em ADRs e documentacao evolutiva  
- **Projeto:** decisoes arquiteturais alinhadas a restricoes de prazo e viabilidade  
