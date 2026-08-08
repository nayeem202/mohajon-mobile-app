#!/usr/bin/env bash
# ============================================================
# Nightly PostgreSQL backup - run as root/deploy via cron
# Keeps 14 daily backups in /opt/haalkhata/backups
# ============================================================
set -euo pipefail

BACKUP_DIR="/opt/haalkhata/backups"
COMPOSE_DIR="/opt/haalkhata"
DB_USER="auth"
DB_NAME="authdb"
KEEP_DAYS=14

mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/authdb-$STAMP.sql.gz"

cd "$COMPOSE_DIR"
docker compose exec -T postgres pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip -9 > "$OUT"

# prune old backups
find "$BACKUP_DIR" -name 'authdb-*.sql.gz' -mtime +"$KEEP_DAYS" -delete

echo "$(date -Is) backup ok: $OUT ($(du -h "$OUT" | cut -f1))"
