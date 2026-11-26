#!/usr/bin/env bash
# Roda todas as migrations num Postgres local limpo e o teste de fumaça.
# Uso: PGHOST=... PGPORT=... PGUSER=postgres scripts/testar_schema.sh
set -euo pipefail
cd "$(dirname "$0")/.."
P="psql -v ON_ERROR_STOP=1 -q -X"
$P -c "drop database if exists luma_teste" -c "create database luma_teste"
$P -d luma_teste -f scripts/supabase_stub.sql >/dev/null
for f in supabase/migrations/*.sql; do $P -d luma_teste -f "$f" >/dev/null; done
out=$($P -d luma_teste -t -A -f scripts/teste_schema.sql)
echo "$out"
if echo "$out" | grep -qx 'f'; then echo "FALHOU: alguma checagem deu falso"; exit 1; fi
echo "OK: schema e fluxos principais passaram"
