# Haalkhata Production Deployment

Live stack on **104.207.92.108** (Ubuntu 24.04, 2 GiB RAM, 1 vCPU, Docker).

| Service | Port | URL |
|---|---|---|
| auth-service (Spring Boot) | 443 | `https://104.207.92.108` |
| haalkhata-service (Spring Boot) | 8443 | `https://104.207.92.108:8443` |
| PostgreSQL 18 | internal only | `postgres:5432` |
| Redis 8 (OTP store) | internal only | `redis:6379` |
| Caddy (reverse proxy + TLS) | 80/443/8443 | — |
| SSH | 22022 | key only |

## Topology

```
Internet ──▶ Caddy (TLS, self-signed CA) ──┬─▶ auth-service:8080
                                           └─▶ haalkhata-service:8081
        Docker network ──▶ postgres:5432, redis:6379 (no public ports)
```

- Both Spring apps share one Postgres database `authdb` (haalkhata uses the `hk` schema).
- `JWT_SECRET` (auth-service) === `TRUSTED_JWT_SECRET` (haalkhata-service): tokens issued by auth-service are accepted by haalkhata-service.
- All traffic is encrypted in transit (Caddy `tls internal`, self-signed). Install the CA to trust it (see below).

## Server layout

```
/opt/haalkhata/
├── .env                    # secrets (chmod 600, never commit)
├── docker-compose.yml
├── Caddyfile
├── Dockerfile.auth / Dockerfile.haalkhata
├── auth-service-0.1.0.jar / haalkhata-service-1.0.0.jar
├── backup.sh               # nightly pg_dump (cron 02:30)
└── backups/                # authdb-YYYYMMDD-HHMMSS.sql.gz, keep 14 days
```

## Connecting

```bash
ssh -p 22022 deploy@104.207.92.108   # key only (root also possible by key)
```

Deploy user has passwordless sudo. Password auth and root password login are disabled;
fail2ban bans after 5 failed attempts. UFW allows only 22022, 80, 443, 8443.

## Daily operations

```bash
# status / logs / restart
docker compose -f /opt/haalkhata/docker-compose.yml ps
docker compose -f /opt/haalkhata/docker-compose.yml logs -f --tail=100 <service>
docker compose -f /opt/haalkhata/docker-compose.yml restart <service>

# deploy a new build: rebuild jar locally, scp to /opt/haalkhata, then
docker compose -f /opt/haalkhata/docker-compose.yml up -d --build
```

## Backups & restore

Backups run automatically at 02:30 daily (cron), keep 14 days.

```bash
# restore latest backup
cd /opt/haalkhata
zcat backups/authdb-YYYYMMDD-HHMMSS.sql.gz | docker compose exec -T postgres psql -U auth -d authdb
```

## Trusting the TLS certificate (mobile app)

Caddy signs certs with its own CA. Two options:

1. **Install the CA** (`deploy/certs/haalkhata-ca.pem` in this repo) on each device,
   or pin it in the app (Android network security config / iOS ATS exception).
2. Add a real domain to the server later and switch the Caddyfile to public
   Let's Encrypt certs (remove `tls internal`).

Flutter app config:

```bash
flutter run --dart-define=USE_CUSTOM_AUTH=true \
  --dart-define=AUTH_BASE_URL=https://104.207.92.108
```

## Security notes

- Secrets live only in `/opt/haalkhata/.env` (generated, chmod 600) — never commit them.
- PostgreSQL/Redis have no published ports; only Caddy faces the internet.
- Containers run as non-root (uid 1001) with memory/CPU limits and log rotation.
- Auto security updates via unattended-upgrades (reboots at 04:00 if needed).
- 2 GiB swap added; JVM heaps capped (auth 256m, haalkhata 384m).
- The VM root password (`Nayeem_123`) no longer works for SSH — rotate it anyway:
  `sudo passwd root`
