#!/usr/bin/env bash
# Guacamole DB(사용자/연결 설정) 백업
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
mkdir -p backups
out="backups/guacamole_$(date +%Y%m%d_%H%M%S).sql.gz"
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$out"
echo "[+] 백업 완료: $out"
