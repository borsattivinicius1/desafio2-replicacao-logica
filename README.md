# Desafio 2 — Replicação Lógica (Publicação / Subscrição)
### Trabalho Prático de Banco de Dados II — IFC Campus Concórdia

Este projeto sobe, com **um único comando Docker**, **2 servidores PostgreSQL**
que replicam **tabelas específicas** entre si usando o modelo de
**Publicação / Subscrição** (replicação lógica, disponível desde o PostgreSQL 10).

Ele cobre os 4 requisitos do desafio:

1. ✅ 2 servidores PostgreSQL configurados (`pg1` e `pg2`)
2. ✅ Publicações e subscrições para tabelas específicas
3. ✅ Replicação seletiva (apenas algumas tabelas)
4. ✅ Inserções/atualizações testadas nos dois lados

---

## 1. Arquitetura

```
        ┌──────────────────────────┐                ┌──────────────────────────┐
        │          pg1             │                │          pg2             │
        │      (porta 15432)       │                │      (porta 15433)       │
        │                          │   pub_vendas   │                          │
        │  clientes  ────────────────────────────▶  clientes  (recebe)        │
        │  produtos  ────────────────────────────▶  produtos  (recebe)        │
        │  pedidos   (NAO publicada — fica so aqui) │                          │
        │                          │                │  avaliacoes (publica)    │
        │  avaliacoes (recebe) ◀───────────────────────────  avaliacoes       │
        │                          │  pub_avaliacoes│                          │
        └──────────────────────────┘                └──────────────────────────┘
```

- Os **dois servidores são independentes** e aceitam escrita (diferente do
  Master-Slave, onde os slaves são só-leitura).
- `pg1` **publica** `clientes` e `produtos`; `pg2` **assina** e recebe essas tabelas.
- `pg2` **publica** `avaliacoes`; `pg1` **assina** e recebe.
- `pedidos` existe **só no pg1** e **não é publicada** → prova da replicação seletiva.

---

## 2. Conceitos (replicação lógica)

| Conceito | O que é |
|----------|---------|
| **PUBLICATION** | Conjunto de tabelas que um servidor disponibiliza para replicação. |
| **SUBSCRIPTION** | Assinatura, no outro servidor, que recebe os dados de uma publicação. |
| **wal_level=logical** | Nível do WAL necessário para a replicação lógica funcionar. |
| **Replicação seletiva** | Só as tabelas dentro da publicação são replicadas. |
| **Bidirecional (aqui)** | Cada servidor publica tabelas diferentes, então há fluxo nos dois sentidos. |

> Diferença para o streaming (físico): a replicação lógica copia **tabelas
> escolhidas** (não o cluster inteiro), e o assinante é um banco **normal e
> gravável**. Por isso ela exige que as tabelas de destino **já existam** no
> assinante (ela replica dados, não a estrutura).

---

## 3. Pré-requisitos

- **Docker** e **Docker Compose** instalados.
- Portas livres: **15432** e **15433** (lado do host).

---

## 4. Como rodar

> Abra o terminal **dentro da pasta `desafio2-replicacao-logica/`**.

Primeiro crie o arquivo `.env` a partir do exemplo (ele guarda as senhas e
**não** vai para o GitHub):

```bash
# Linux / Mac / Git Bash
cp .env.example .env

# Windows PowerShell
Copy-Item .env.example .env
```

Depois suba o cluster:

```bash
docker compose up -d
```

Isso sobe `pg1`, `pg2` e, quando os dois ficam saudáveis, o contêiner `setup`
cria as duas subscrições automaticamente e encerra. Para conferir:

```bash
docker compose ps
docker compose logs setup      # deve mostrar "Replicacao logica configurada"
```

---

## 5. Testar (demonstração)

```bash
bash scripts/demo.sh
```

A demo prova os 4 requisitos em sequência:
1. Os 2 servidores e suas tabelas
2. As publicações e subscrições criadas
3. **Replicação seletiva** — insere `cliente` e `pedido` no `pg1`: o cliente
   aparece no `pg2`, mas `pedidos` não (não foi publicada)
4. **Update** replicando (`pg1 → pg2`) e **escrita no outro lado**
   (`pg2 → pg1`, via `avaliacoes`)

Para ver só o status da replicação:

```bash
bash scripts/status.sh
```

---

## 6. Como conectar (DBeaver, pgAdmin, psql)

| Servidor | Host | Porta | Usuário | Senha | Banco |
|----------|------|-------|---------|-------|-------|
| pg1 | localhost | 15432 | admin | admin123 | bd2 |
| pg2 | localhost | 15433 | admin | admin123 | bd2 |

> **Por que 15432/15433 e não 5432/5433?** Para não conflitar com um PostgreSQL
> instalado direto na máquina (que costuma ocupar a 5432). As portas internas
> dos contêineres continuam 5432; só o lado do host foi remapeado. Os scripts de
> demo usam `docker exec`, então não dependem dessas portas.

```bash
docker exec -it bd2_pg1 psql -U admin -d bd2
```

---

## 7. Comandos úteis

```bash
docker compose logs -f pg1      # logs de um servidor
docker compose stop             # para (mantém os dados)
docker compose start            # religa
docker compose down -v && docker compose up -d   # RESET total (recomeça do zero)
```

---

## 8. Análise (para a documentação e o seminário)

**Vantagens**
- Replica **apenas as tabelas escolhidas** (seletiva), economizando recursos.
- O assinante é um **banco gravável** — pode ter dados próprios e índices diferentes.
- Permite **fluxo bidirecional** (cada lado publica o que quiser).
- Funciona **entre versões diferentes** do PostgreSQL.

**Desvantagens**
- **Não replica DDL**: as tabelas precisam ser criadas manualmente no assinante.
- Exige **chave primária** (ou REPLICA IDENTITY) para replicar UPDATE/DELETE.
- Em fluxo bidirecional, é preciso cuidado com **conflitos** (mesma linha nos dois lados).
- Tem mais overhead que a replicação física para volumes muito grandes.

**Principais desafios encontrados**
- Garantir `wal_level=logical` nos dois servidores.
- Criar as **tabelas de destino antes** das subscrições (a replicação lógica
  não copia a estrutura, só os dados).
- Criar as subscrições **depois** que os dois servidores sobem (resolvido com o
  contêiner `setup` + `depends_on: service_healthy`).
- Permissões: usuário de replicação com `REPLICATION` e `SELECT` nas tabelas
  publicadas, além de liberar o `pg_hba.conf`.

---


