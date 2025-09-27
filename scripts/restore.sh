#!/usr/bin/env bash
set -euo pipefail

DUMP_FILE="${1:-}"
TARGET_DB_URI="${2:-}"

if [[ -z "$DUMP_FILE" || -z "$TARGET_DB_URI" ]]; then
  echo "Usage: restore.sh /path/to/file.dump postgresql://user:pass@host:port/dbname"
  exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
  echo "[ERR] pg_restore not found. Install postgresql-client."
  exit 1
fi

# Пример: на чистую БД (раскомментируйте при необходимости)
# dropdb "${TARGET_DB_URI}"
# createdb "${TARGET_DB_URI}"

echo "[INFO] Restoring $DUMP_FILE -> $TARGET_DB_URI"
pg_restore --clean --if-exists --no-owner --no-privileges -d "$TARGET_DB_URI" "$DUMP_FILE"
echo "[OK ] Restore finished"
