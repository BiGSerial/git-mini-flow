# mini-flow

Automação local em Bash para simplificar o uso diário do Git em projetos com fluxo baseado em `main` e `develop`.

O `mini-flow` cria comandos como `git start`, `git hotfix`, `git finish`, `git pause`, `git resume`, `git release` e `git cleanup`, automatizando tarefas comuns de branch, merge, stash, publicação e versionamento.

## Objetivo

Reduzir comandos repetitivos, padronizar o fluxo de trabalho e evitar erros manuais em operações Git do dia a dia.

## Fluxo adotado

- `main`: branch de produção
- `develop`: branch de integração
- `feature/*`: novas funcionalidades
- `fix/*`: correções comuns
- `hotfix/*`: correções urgentes de produção
- `docs/*`: documentação
- `refactor/*`: refatorações
- `test/*`: testes

## Exemplos

```bash
git start feature nova-tela
git start feature "nova tela"
git hotfix corrige-login
git pause "trocar de demanda"
git resume
git finish
git release v1.2.0 "Release v1.2.0"
