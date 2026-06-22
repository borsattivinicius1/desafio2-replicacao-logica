#!/bin/bash
# Inicializa o SERVIDOR 2 (pg2):
#  - cria as tabelas que vao RECEBER do pg1 (clientes, produtos) — vazias
#  - cria a tabela avaliacoes (com dados) e a PUBLICA para o pg1
set -e

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOSQL
-- Usuario dedicado da replicacao logica
CREATE ROLE $REPL_USER WITH REPLICATION LOGIN PASSWORD '$REPL_PASSWORD';

-- ===== Tabelas que VEM do pg1 (precisam existir, comecam vazias) =====
CREATE TABLE clientes (
  id        INT PRIMARY KEY,
  nome      TEXT NOT NULL,
  cidade    TEXT,
  criado_em TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE produtos (
  id    INT PRIMARY KEY,
  nome  TEXT NOT NULL,
  preco NUMERIC(10,2) NOT NULL
);

-- ===== Tabela propria do pg2, que sera PUBLICADA para o pg1 =====
CREATE TABLE avaliacoes (
  id         INT PRIMARY KEY,
  produto_id INT,
  nota       INT,
  comentario TEXT
);

INSERT INTO avaliacoes (id, produto_id, nota, comentario) VALUES
 (1,1,5,'Excelente notebook'),
 (2,2,4,'Mouse bom e barato');

CREATE PUBLICATION pub_avaliacoes FOR TABLE avaliacoes;

GRANT SELECT ON avaliacoes TO $REPL_USER;
EOSQL

cat >> "$PGDATA/pg_hba.conf" <<EOF

# --- Regras para replicacao logica (Trabalho BD II - Desafio 2) ---
host    all             $REPL_USER      0.0.0.0/0       scram-sha-256
host    all             all             0.0.0.0/0       scram-sha-256
EOF

echo ">>> [pg2] Inicializado: publicacao pub_avaliacoes criada."
