# mini-flow

Automação local em Bash para simplificar o uso diário do Git em projetos que trabalham com `main`, `develop`, branches de tarefa e releases versionadas.

O **mini-flow** cria uma camada de comandos curtos em cima do Git, permitindo iniciar tarefas, publicar branches, pausar trabalho, retomar alterações, finalizar demandas, criar hotfixes e gerar releases com menos digitação e menos risco de erro operacional.

Ele não substitui o Git. Ele apenas coloca trilhos em um fluxo comum de desenvolvimento, reduzindo comandos repetitivos e padronizando decisões do dia a dia.

---

## Visão geral

Em vez de repetir comandos como:

```bash
git checkout develop
git pull origin develop --ff-only
git checkout -b feature/minha-demanda
```

Você usa:

```bash
git start feature minha-demanda
```

Também funciona com nomes compostos:

```bash
git start feature "minha demanda"
git start feature minha demanda
```

Para uma correção urgente em produção:

```bash
git hotfix corrige-login
```

E para finalizar:

```bash
git finish
```

O comportamento muda conforme o tipo da branch:

- `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `chore/*` e `test/*` nascem de `develop` e retornam para `develop`;
- `hotfix/*` nasce de `main`, retorna para `main` e depois também para `develop`.

---

## Para quem se destina

O **mini-flow** foi pensado para desenvolvedores e pequenas equipes que usam Git diariamente, mas querem evitar repetição mecânica de comandos e reduzir erros comuns no fluxo de branches.

Ele é especialmente útil para:

- desenvolvedores que trabalham com `main` e `develop`;
- projetos com produção e desenvolvimento separados;
- times pequenos ou médios que querem um fluxo padronizado sem ferramenta pesada;
- ambientes Linux, WSL ou servidores de desenvolvimento;
- projetos Laravel, PHP, Node, Python ou qualquer stack versionada com Git;
- cenários com tarefas paralelas, hotfixes, releases e troca frequente de contexto;
- quem gosta da ideia do Git Flow, mas prefere algo mais direto e menos cerimonial.

---

## O problema que ele resolve

O Git é poderoso, mas o uso diário costuma gerar pequenas fricções:

- lembrar qual branch deve originar cada tipo de tarefa;
- trocar manualmente para `develop` antes de criar uma feature;
- atualizar a branch base antes de iniciar trabalho;
- publicar branch com `-u`;
- finalizar uma branch e lembrar de apagar local/remoto;
- pausar uma tarefa sem perder alterações;
- retomar trabalho aplicando stash corretamente;
- criar hotfix de produção sem esquecer de devolver a correção para `develop`;
- fazer release com merge e tag de forma padronizada.

O **mini-flow** automatiza essas decisões recorrentes.

---

## Diferenciais

### 1. Fluxo simples, mas profissional

O projeto segue uma lógica inspirada no Git Flow, porém simplificada:

```text
main       = produção
develop    = integração
feature/*  = novas funcionalidades
fix/*      = correções comuns
hotfix/*   = correções urgentes de produção
release    = promoção de develop para main com tag
```

A ideia é manter organização profissional sem transformar cada tarefa em uma missa de trinta comandos.

---

### 2. Hotfix com comportamento correto

Hotfix é tratado como caso especial.

Uma branch `hotfix/*` nasce de `main`, pois representa correção de algo que já está em produção.

Ao finalizar um hotfix, o `mini-flow` faz:

```text
hotfix/* -> main
hotfix/* -> develop
```

Isso evita que uma correção feita em produção seja perdida no próximo release vindo de `develop`.

---

### 3. Aceita nomes com ou sem aspas

Você pode criar branches de três formas:

```bash
git start feature teste-do-instalador
git start feature "teste do instalador"
git start feature teste do instalador
```

Todas geram uma branch parecida com:

```text
feature/teste-do-instalador
```

O script normaliza o nome da branch automaticamente.

---

### 4. Menos comandos repetitivos

O fluxo reduz várias operações para comandos curtos:

```bash
git start feature nova-tela
git publish
git pause "trocar de demanda"
git resume
git finish
```

Isso ajuda principalmente em contextos com muitas tarefas pequenas, interrupções ou demandas paralelas.

---

### 5. Pause e resume com stash

O comando `git pause` salva o estado atual da branch usando stash, registra a branch de origem e volta para a branch base correta.

Depois, `git resume` retorna para a branch anterior, atualiza em relação à base e reaplica o stash.

Exemplo:

```bash
git pause "interrompido por demanda urgente"
git resume
```

Para branches normais, a base é `develop`.

Para `hotfix/*`, a base é `main`.

---

### 6. Segurança operacional

O script evita executar operações perigosas quando o repositório está em estado delicado.

Ele bloqueia ações se houver:

- merge pendente;
- rebase em andamento;
- cherry-pick em andamento;
- workspace sujo em comandos que exigem limpeza;
- tentativa de finalizar branch fixa como `main` ou `develop`;
- tentativa de apagar branches que não seguem prefixos esperados.

Além disso, a exclusão remota só ocorre em branches de trabalho com prefixos conhecidos.

---

### 7. Instalador local

O projeto inclui um instalador que:

- copia o `mini-flow` para `~/bin/mini-flow`;
- cria backup do script anterior, se existir;
- dá permissão de execução;
- configura aliases globais no Git;
- tenta garantir `~/bin` no `PATH`;
- permite desinstalação.

---

## Branches utilizadas

Por padrão:

```text
main     -> produção
develop  -> integração/desenvolvimento
origin   -> remoto padrão
```

Esses valores podem ser alterados com variáveis de ambiente:

```bash
export MF_BASE_BRANCH=develop
export MF_PROD_BRANCH=main
export MF_REMOTE_NAME=origin
```

---

## Prefixos aceitos

Branches de trabalho aceitas:

```text
feature/*
fix/*
hotfix/*
chore/*
refactor/*
docs/*
test/*
```

---

## Comandos disponíveis

### Ajuda

```bash
git helpme
```

Ou diretamente:

```bash
mini-flow help
```

---

### Criar feature, fix, docs, refactor, chore ou test

```bash
git start feature nova-tela
git start fix ajuste-relatorio
git start docs atualiza-readme
git start refactor reorganiza-service
```

Todas essas branches nascem de `develop`.

---

### Criar hotfix

```bash
git hotfix corrige-login
```

Ou:

```bash
git start hotfix corrige-login
```

Branches `hotfix/*` nascem de `main`.

---

### Publicar branch atual

```bash
git publish
```

Executa o push com upstream:

```bash
git push -u origin branch-atual
```

---

### Sincronizar branch atual

```bash
git sync
```

Para branches comuns, aplica rebase com `origin/develop`.

Para `hotfix/*`, aplica rebase com `origin/main`.

---

### Pausar trabalho atual

```bash
git pause "motivo da pausa"
```

Exemplo:

```bash
git pause "parando para corrigir produção"
```

O comando salva alterações em stash, registra a branch atual e volta para a base correta.

---

### Retomar trabalho pausado

```bash
git resume
```

O comando volta para a branch pausada, sincroniza com a base correta e reaplica o stash salvo.

---

### Finalizar branch

```bash
git finish
```

Comportamento por tipo:

| Branch atual | Resultado |
|---|---|
| `feature/*` | merge em `develop` |
| `fix/*` | merge em `develop` |
| `docs/*` | merge em `develop` |
| `refactor/*` | merge em `develop` |
| `chore/*` | merge em `develop` |
| `test/*` | merge em `develop` |
| `hotfix/*` | merge em `main` e depois em `develop` |

---

### Abortar branch local

```bash
git abort
```

Remove a branch local atual, desde que ela seja uma branch de trabalho reconhecida.

---

### Abortar branch local e remota

```bash
git abort-remote
```

Remove a branch local e tenta remover a branch remota, desde que ela siga um prefixo permitido.

Para impedir exclusão remota automática:

```bash
export MF_NO_DELETE_REMOTE=1
```

---

### Criar release

```bash
git release v1.2.0 "Release v1.2.0"
```

O release deve ser executado a partir de `develop`.

Fluxo:

```text
develop -> main
tag vX.Y.Z
```

---

### Limpar branches já mergeadas

```bash
git cleanup
```

Remove branches locais de trabalho que já foram integradas em `develop`.

---

## Aliases instalados

O instalador configura:

```bash
git start
git hotfix
git publish
git finish
git abort
git abort-remote
git release
git cleanup
git pause
git resume
git sync
git helpme
```

E atalhos auxiliares:

```bash
git co
git cob
git br
git st
git lg
```

---

## Instalação

Baixe o instalador e execute:

```bash
chmod +x install-mini-flow.sh
./install-mini-flow.sh
```

Depois, recarregue o terminal:

```bash
source ~/.bashrc
```

Ou feche e abra o terminal.

---

## Validando a instalação

```bash
command -v mini-flow
git helpme
git config --global --get-regexp '^alias\.'
```

Dentro de um repositório:

```bash
git st
git start feature teste-do-instalador
```

---

## Desinstalação

```bash
./install-mini-flow.sh --uninstall
```

A desinstalação remove o binário `mini-flow` e os aliases globais criados.

Ela não remove automaticamente alterações de `PATH` no `.bashrc`, `.zshrc` ou `.profile`, para evitar apagar configuração manual do usuário.

---

## Exemplo de uso diário

```bash
git start feature painel-juridico
# trabalha na demanda
git publish
# abre PR/MR, se aplicável
git finish
```

---

## Exemplo de pausa e retomada

```bash
git start feature relatorio-ads
# começou a alterar arquivos

git pause "interrompido por demanda urgente"

git hotfix corrige-erro-producao
# corrige, commita
git finish

git resume
# volta para feature/relatorio-ads
```

---

## Exemplo de hotfix

```bash
git hotfix corrige-login
# corrige o problema
git add .
git commit -m "Corrige erro no login"
git finish
```

Resultado:

```text
hotfix/corrige-login -> main
hotfix/corrige-login -> develop
```

---

## Filosofia do projeto

O **mini-flow** foi criado para ser pequeno, previsível e fácil de entender.

Ele não depende de frameworks, pacotes externos ou ferramentas de terceiros. É apenas Bash e Git.

A proposta é automatizar o óbvio, proteger contra erros comuns e manter o desenvolvedor focado no trabalho real, não na coreografia dos comandos.

---

## Limitações

O mini-flow não substitui:

- revisão de código;
- pull requests;
- pipelines de CI/CD;
- testes automatizados;
- política de versionamento da equipe;
- conhecimento básico de Git.

Ele é uma ferramenta de produtividade local, não um sistema completo de governança de código.

---

## Quando talvez não usar

Este fluxo pode não ser ideal para projetos que usam:

- trunk-based development puro;
- deploy contínuo direto da `main`;
- branches por ambiente como `staging`, `homolog` e `production`;
- regras rígidas de Pull Request sem merge local;
- ferramentas corporativas que já automatizam todo o fluxo.

Nesses casos, o script pode ser adaptado ou usado apenas parcialmente.

---

## Licença

Este projeto está licenciado sob a licença MIT.

Consulte o arquivo [LICENSE](./LICENSE) para mais detalhes.
