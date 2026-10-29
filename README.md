# Apache Guacamole 원격 접속 서버

브라우저만으로 RDP / SSH / VNC / Telnet 원격 접속을 제공하는 Docker Compose 구성입니다.

```
[브라우저] --HTTPS--> [nginx :443] --> [guacamole :8080] --> [guacd :4822] --RDP/SSH/VNC--> [대상 서버]
                                              |
                                        [PostgreSQL] (사용자·연결·권한·이력)
```

## 구성 요소
| 서비스 | 역할 |
|---|---|
| `guacd` | 원격 프로토콜(RDP/SSH/VNC) 처리 데몬 |
| `guacamole` | 웹 애플리케이션 (TOTP 2단계 인증, 브루트포스 차단 포함) |
| `postgres` | 사용자/연결 설정 저장 |
| `nginx` | HTTPS 종료, WebSocket 프록시, HTTP→HTTPS 리다이렉트 |

## 설치
요구 사항: Docker 20.10+ / Docker Compose v2, openssl

```bash
scripts/setup.sh        # .env, DB 스키마, 자체 서명 인증서 생성
docker compose up -d
```

`https://<서버주소>/` 접속 → 초기 계정 **guacadmin / guacadmin**
(최초 로그인 시 TOTP 등록 화면이 나옵니다 — Google Authenticator 등으로 QR 스캔)

## 설치 직후 보안 조치 (필수)
1. 새 관리자 계정 생성 → 모든 관리 권한 부여
2. 새 계정으로 로그인 후 `guacadmin` 삭제 또는 비활성화
3. 방화벽에서 80/443만 개방 (4822, 5432, 8080은 외부 노출 안 됨)
4. 공인 도메인이 있으면 정식 인증서 적용:
   ```bash
   scripts/letsencrypt.sh guac.example.com admin@example.com
   ```

## 연결 추가 (설정 → 연결 → 새 연결)
| 프로토콜 | 주요 입력값 |
|---|---|
| **RDP** (Windows) | 호스트명, 포트 3389, 사용자/비밀번호, 보안 모드 `any` 또는 `NLA`, *서버 인증서 무시* 체크 |
| **SSH** (Linux) | 호스트명, 포트 22, 사용자 + 비밀번호 또는 개인키 |
| **VNC** | 호스트명, 포트 5900, 비밀번호 |

- 파일 전송(RDP): *드라이브 활성화* 체크, 드라이브 경로 `/drive/${GUAC_USERNAME}`, *자동 생성* 체크
- 세션 녹화: 녹화 경로 `/record`, 녹화 이름 `${GUAC_USERNAME}-${GUAC_DATE}-${GUAC_TIME}`, *자동 생성* 체크
  → 관리 화면 *이력*에서 바로 재생 가능

> 대상 호스트명은 **guacd 컨테이너 기준**으로 해석됩니다. 같은 서버의 호스트 머신에 접속하려면 Docker 브리지 게이트웨이 IP(보통 `172.17.0.1`) 또는 호스트의 LAN IP를 사용하세요.

## 운영
```bash
docker compose logs -f guacamole   # 로그
scripts/backup.sh                  # DB 백업 → backups/
docker compose pull && docker compose up -d   # 업데이트
```
버전을 올릴 때는 `.env`의 `GUAC_VERSION` 변경 후, 릴리스 노트의 DB 업그레이드 스크립트 적용 여부를 확인하세요.

## 문제 해결
| 증상 | 원인/조치 |
|---|---|
| 로그인 화면 진입 후 "연결 오류" | `docker compose logs guacd` 확인, 대상 서버 방화벽/포트 확인 |
| RDP 즉시 끊김 | 보안 모드 `any`, *서버 인증서 무시* 체크, 대상 PC의 원격 데스크톱 허용 확인 |
| 로그인 시 DB 오류 | `init/initdb.sql`이 비어있거나 늦게 생성됨 → `docker compose down && rm -rf data/postgres && docker compose up -d` (데이터 초기화 주의) |
| 화면이 멈춤 | nginx WebSocket 설정(`Upgrade` 헤더) 및 프록시 타임아웃 확인 |
