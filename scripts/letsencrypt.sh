#!/usr/bin/env bash
# Let's Encrypt 정식 인증서 발급 (도메인이 이 서버를 가리키고 80 포트가 열려 있어야 함)
# 사용법: scripts/letsencrypt.sh guac.example.com admin@example.com
set -euo pipefail
cd "$(dirname "$0")/.."
domain=${1:?도메인을 입력하세요}
email=${2:?이메일을 입력하세요}

docker compose stop nginx
docker run --rm -p 80:80 -v "$PWD/data/letsencrypt:/etc/letsencrypt" \
  certbot/certbot certonly --standalone --non-interactive --agree-tos \
  -m "$email" -d "$domain"

live="data/letsencrypt/live/$domain"
cp -L "$live/fullchain.pem" nginx/ssl/cert.pem
cp -L "$live/privkey.pem"   nginx/ssl/key.pem
chmod 600 nginx/ssl/key.pem
docker compose start nginx
echo "[+] $domain 인증서 적용 완료 (90일마다 재실행 필요 → cron 등록 권장)"
