#!/usr/bin/env bash
set -euo pipefail

backup_dir=/opt/mohajon/backups
stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
tmp="$backup_dir/db-$stamp.dump.tmp"
final="$backup_dir/db-$stamp.dump"

trap 'rm -f -- "$tmp"' EXIT
cd /opt/mohajon/deploy
docker compose --env-file ../.env exec -T postgres \
  pg_dump --username=mohajon --format=custom mohajon > "$tmp"
test -s "$tmp"
chmod 600 "$tmp"
mv -- "$tmp" "$final"
find "$backup_dir" -maxdepth 1 -type f -name 'db-*.dump' -mtime +14 -delete
