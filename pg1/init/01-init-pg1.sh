#!/bin/bash
# Inicializa o SERVIDOR 1 (pg1):
#  - cria as tabelas e os dados
#  - PUBLICA apenas clientes e produtos (replicacao SELETIVA: pedidos NAO entra)
#  - prepara a tabela avaliacoes (vazia) para RECEBER do pg2
set -e

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOSQL
-- Usuario dedicado da replicacao logica
CREATE ROLE $REPL_USER WITH REPLICATION LOGIN PASSWORD '$REPL_PASSWORD';

-- ===== Tabelas =====
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

-- Esta tabela existe SO no pg1 e NAO sera publicada (prova da replicacao seletiva)
CREATE TABLE pedidos (
  id         INT PRIMARY KEY,
  cliente_id INT,
  total      NUMERIC(10,2),
  status     TEXT
);

-- Tabela que sera RECEBIDA do pg2 (precisa existir aqui, comeca vazia)
CREATE TABLE avaliacoes (
  id         INT PRIMARY KEY,
  produto_id INT,
  nota       INT,
  comentario TEXT
);

-- ===== Dados iniciais =====
INSERT INTO clientes (id, nome, cidade) VALUES
 (1,'Ana Souza','Chapeco'),
 (2,'Bruno Lima','Concordia'),
 (3,'Carla Mendes','Joacaba');

INSERT INTO produtos (id, nome, preco) VALUES
 (1,'Notebook',4500.00),
 (2,'Mouse',80.00),
 (3,'Teclado',320.00);

INSERT INTO pedidos (id, cliente_id, total, status) VALUES
 (1,1,4580.00,'pago'),
 (2,3,320.00,'novo');

-- ===== PUBLICACAO SELETIVA: somente clientes e produtos =====
CREATE PUBLICATION pub_vendas FOR TABLE clientes, produtos;

-- O usuario de replicacao precisa de SELECT nas tabelas publicadas
GRANT SELECT ON clientes, produtos TO $REPL_USER;
EOSQL

# Libera a conexao do usuario de replicacao (e do admin) pela rede do Docker
cat >> "$PGDATA/pg_hba.conf" <<EOF

# --- Regras para replicacao logica (Trabalho BD II - Desafio 2) ---
host    all             $REPL_USER      0.0.0.0/0       scram-sha-256
host    all             all             0.0.0.0/0       scram-sha-256
EOF

echo ">>> [pg1] Inicializado: publicacao pub_vendas (clientes, produtos) criada."
