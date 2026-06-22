#!/bin/bash
# Mostra o estado da replicacao logica nos 2 servidores.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$DIR/.env"; set +a
P1(){ docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" bd2_pg1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"; }
P2(){ docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" bd2_pg2 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"; }

echo "===== pg1 ====="
echo "- Publicacoes:"; P1 "SELECT pubname FROM pg_publication;"
echo "- Subscricoes:"; P1 "SELECT subname, subenabled FROM pg_subscription;"
echo "- Quem esta replicando a partir do pg1 (pg_stat_replication):"
P1 "SELECT application_name, state FROM pg_stat_replication;"

echo ""
echo "===== pg2 ====="
echo "- Publicacoes:"; P2 "SELECT pubname FROM pg_publication;"
echo "- Subscricoes:"; P2 "SELECT subname, subenabled FROM pg_subscription;"
echo "- Quem esta replicando a partir do pg2 (pg_stat_replication):"
P2 "SELECT application_name, state FROM pg_stat_replication;"
