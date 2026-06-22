#!/bin/bash
# ============================================================
#  DEMO - Replicacao Logica (Desafio 2)
#  Prova os 4 requisitos: 2 servidores, publicacoes/subscricoes,
#  replicacao seletiva e escrita nos dois lados.
#  Uso: bash scripts/demo.sh
# ============================================================
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"
set -a; source "$DIR/.env"; set +a

P1(){ docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" bd2_pg1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"; }
P2(){ docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" bd2_pg2 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"; }
pause(){ if [ -t 0 ]; then read -rp $'\n>>> Pressione [Enter] para continuar...\n'; else sleep 3; fi; }
banner(){ echo; echo "============================================================"; echo "  $1"; echo "============================================================"; }

banner "REQUISITO 1 - Os 2 servidores PostgreSQL no ar"
echo "--- Tabelas no pg1 (publica clientes/produtos, tem pedidos so local) ---"
P1 "\dt"
echo "--- Tabelas no pg2 (recebe clientes/produtos, publica avaliacoes) ---"
P2 "\dt"
pause

banner "REQUISITO 2 - Publicacoes e subscricoes (tabelas especificas)"
echo "--- pg1: publicacao e o que ela contem ---"
P1 "SELECT pubname FROM pg_publication;"
P1 "SELECT pubname, tablename FROM pg_publication_tables ORDER BY 1,2;"
P1 "SELECT subname FROM pg_subscription;"
echo "--- pg2: publicacao e subscricao ---"
P2 "SELECT pubname, tablename FROM pg_publication_tables ORDER BY 1,2;"
P2 "SELECT subname FROM pg_subscription;"
pause

banner "REQUISITO 3 - Replicacao SELETIVA (clientes/produtos sim, pedidos NAO)"
echo ">>> Estado inicial replicado: pg2 ja recebeu clientes e produtos do pg1."
P2 "SELECT count(*) AS clientes_no_pg2 FROM clientes;"
P2 "SELECT count(*) AS produtos_no_pg2 FROM produtos;"
echo ">>> Inserindo um novo cliente e um novo pedido NO pg1..."
P1 "INSERT INTO clientes (id,nome,cidade) VALUES (4,'Diego Rocha','Xanxere');"
P1 "INSERT INTO pedidos  (id,cliente_id,total,status) VALUES (3,4,999.00,'novo');"
sleep 2
echo ">>> No pg2: o CLIENTE novo apareceu (foi publicado)..."
P2 "SELECT id, nome, cidade FROM clientes ORDER BY id;"
echo ">>> No pg2: a tabela PEDIDOS nem existe, pois NAO foi publicada (esperado falhar):"
P2 "SELECT count(*) FROM pedidos;" || echo ">>> OK: pedidos nao foi replicada (replicacao seletiva)."
pause

banner "REQUISITO 4a - UPDATE tambem replica (pg1 -> pg2)"
echo ">>> Atualizando a cidade da Ana no pg1..."
P1 "UPDATE clientes SET cidade='Florianopolis' WHERE id=1;"
sleep 2
echo ">>> No pg2 a alteracao apareceu:"
P2 "SELECT id, nome, cidade FROM clientes WHERE id=1;"
pause

banner "REQUISITO 4b - Escrita no OUTRO lado (pg2 -> pg1)"
echo ">>> Estado inicial: pg1 ja recebeu as avaliacoes publicadas pelo pg2."
P1 "SELECT count(*) AS avaliacoes_no_pg1 FROM avaliacoes;"
echo ">>> Inserindo uma nova avaliacao NO pg2..."
P2 "INSERT INTO avaliacoes (id,produto_id,nota,comentario) VALUES (3,3,5,'Teclado otimo');"
sleep 2
echo ">>> No pg1 a avaliacao nova apareceu (replicou no sentido pg2 -> pg1):"
P1 "SELECT id, produto_id, nota, comentario FROM avaliacoes ORDER BY id;"
pause

banner "RESUMO"
echo "1) Dois servidores PostgreSQL independentes (pg1 e pg2)"
echo "2) Publicacoes e subscricoes para tabelas especificas"
echo "3) Replicacao seletiva: clientes/produtos replicam, pedidos NAO"
echo "4) Insercoes e atualizacoes funcionam nos DOIS sentidos:"
echo "     pg1 -> pg2 (clientes, produtos)   |   pg2 -> pg1 (avaliacoes)"
echo
echo "Para resetar:  docker compose down -v && docker compose up -d"
