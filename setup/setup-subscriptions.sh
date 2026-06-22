#!/bin/bash
# Cria as SUBSCRIPTIONS depois que pg1 e pg2 estao no ar.
#  - pg2 assina pub_vendas do pg1   -> recebe clientes e produtos
#  - pg1 assina pub_avaliacoes do pg2 -> recebe avaliacoes
# É idempotente: se a subscription ja existir, nao recria.
set -e
export PGPASSWORD="$POSTGRES_PASSWORD"

CONN_PG1="host=pg1 port=5432 dbname=$POSTGRES_DB user=$REPL_USER password=$REPL_PASSWORD"
CONN_PG2="host=pg2 port=5432 dbname=$POSTGRES_DB user=$REPL_USER password=$REPL_PASSWORD"

echo ">>> [setup] Aguardando pg1 e pg2 aceitarem conexoes..."
until pg_isready -h pg1 -U "$POSTGRES_USER" >/dev/null 2>&1; do sleep 2; done
until pg_isready -h pg2 -U "$POSTGRES_USER" >/dev/null 2>&1; do sleep 2; done
sleep 2

# pg2 assina o pg1
if ! psql -h pg2 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
     "SELECT 1 FROM pg_subscription WHERE subname='sub_vendas'" | grep -q 1; then
  echo ">>> [setup] Criando sub_vendas no pg2 (assina pub_vendas do pg1)..."
  psql -h pg2 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
    "CREATE SUBSCRIPTION sub_vendas CONNECTION '$CONN_PG1' PUBLICATION pub_vendas;"
else
  echo ">>> [setup] sub_vendas ja existe no pg2."
fi

# pg1 assina o pg2
if ! psql -h pg1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
     "SELECT 1 FROM pg_subscription WHERE subname='sub_avaliacoes'" | grep -q 1; then
  echo ">>> [setup] Criando sub_avaliacoes no pg1 (assina pub_avaliacoes do pg2)..."
  psql -h pg1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
    "CREATE SUBSCRIPTION sub_avaliacoes CONNECTION '$CONN_PG2' PUBLICATION pub_avaliacoes;"
else
  echo ">>> [setup] sub_avaliacoes ja existe no pg1."
fi

echo ">>> [setup] Replicacao logica configurada nos dois sentidos."
