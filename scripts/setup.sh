#!/usr/bin/env bash
# Guacamole 최초 설치 스크립트: .env 생성, DB 스키마 생성, 인증서 생성
set -euo pipefail
cd "$(dirname "$0")/.."

# 1) .env 생성 + DB 비밀번호 자동 생성
if [[ ! -f .env ]]; then
  cp .env.example .env
  pw=$(openssl rand -base64 24 | tr -d '/+=')
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${pw}/" .env
  echo "[+] .env 생성 완료 (DB 비밀번호 자동 생성)"
fi
set -a; source .env; set +a

# 2) 데이터 디렉터리
mkdir -p data/{postgres,drive,record} nginx/ssl init
# guacd(uid 1000)가 녹화/드라이브에 쓸 수 있도록
chmod 0777 data/drive data/record

# 3) DB 초기화 SQL 생성 (공식 이미지의 initdb.sh 사용)
if [[ ! -s init/initdb.sql ]]; then
  docker run --rm "guacamole/guacamole:${GUAC_VERSION}" \
    /opt/guacamole/bin/initdb.sh --postgresql > init/initdb.sql
  echo "[+] init/initdb.sql 생성 완료"
fi

# 4) 자체 서명 인증서 (실서비스는 scripts/letsencrypt.sh 사용 권장)
if [[ ! -f nginx/ssl/cert.pem ]]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
    -keyout nginx/ssl/key.pem -out nginx/ssl/cert.pem \
    -subj "/CN=${SERVER_NAME}" \
    -addext "subjectAltName=DNS:${SERVER_NAME},DNS:localhost,IP:127.0.0.1"
  chmod 600 nginx/ssl/key.pem
  echo "[+] 자체 서명 인증서 생성 완료 (CN=${SERVER_NAME})"
fi

echo
echo "준비 완료. 다음 명령으로 기동하세요:"
echo "  docker compose up -d"
echo "접속: https://${SERVER_NAME}/   (초기 계정 guacadmin / guacadmin → 즉시 변경!)"
