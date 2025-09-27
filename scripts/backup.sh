#!/usr/bin/env bash
set -euo pipefail

# Загружаем конфиг
ENV_FILE="${ENV_FILE:-/etc/pg-multi-backup.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +o allexport
fi

# Проверки
: "${BACKUP_ROOT:?BACKUP_ROOT not set}"
: "${RETENTION:?RETENTION not set}"
: "${LOG_DIR:?LOG_DIR not set}"

mkdir -p "$BACKUP_ROOT" "$LOG_DIR"

# Логи
TS="$(date +'%Y-%m-%d_%H-%M-%S')"
MONTH="$(date +'%Y-%m')"
LOG_FILE="$LOG_DIR/backup-$MONTH.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "====== [$TS] START BACKUP ======"

# Собираем все переменные *DATABASE_URL из окружения
mapfile -t URL_VARS < <(env | grep -E '^[A-Za-z0-9_]+DATABASE_URL=' | cut -d= -f1)

if (( ${#URL_VARS[@]} == 0 )); then
  echo "[ERR] No *DATABASE_URL variables found"
  exit 1
fi

# Функция нормализации URI для pg_dump
normalize_uri() {
  local raw="$1"
  # заменяем префикс SQLAlchemy: postgresql+asyncpg:// -> postgresql://
  echo "$raw" | sed -E 's/^postgresql\+[^:]+:/postgresql:/'
}

# Имя БД из URI (последний сегмент)
dbname_from_uri() {
  local uri="$1"
  # урезаем query/фрагменты
  local base="${uri%%\?*}"
  base="${base%%#*}"
  # имя после последнего /
  echo "${base##*/}"
}

# Основной цикл
for var in "${URL_VARS[@]}"; do
  RAW_URI="${!var}"
  URI="$(normalize_uri "$RAW_URI")"
  DB_NAME="$(dbname_from_uri "$URI")"
  if [[ -z "$DB_NAME" ]]; then
    echo "[WARN] Cannot parse db name for $var -> $RAW_URI"
    continue
  fi

  # Каталог для конкретной БД
  DB_DIR="$BACKUP_ROOT/$DB_NAME"
  mkdir -p "$DB_DIR"

  # Имя дампа
  DUMP_FILE="$DB_DIR/${DB_NAME}__${TS}.dump"

  echo "[INFO] Dumping $DB_NAME from $var"

  # pg_dump
  if ! command -v pg_dump >/dev/null 2>&1; then
    echo "[ERR] pg_dump not found. Install postgresql-client."
    exit 1
  fi

  # Выполняем дамп в custom-формате (-Fc)
  if ! pg_dump --dbname="$URI" -Fc ${PG_DUMP_OPTS:-} -f "$DUMP_FILE"; then
    echo "[ERR] pg_dump failed for $DB_NAME"
    continue
  fi

  # Проверка целостности (pg_restore -l)
  if ! pg_restore -l "$DUMP_FILE" >/dev/null 2>&1; then
    echo "[ERR] integrity check failed for $DUMP_FILE"
    rm -f "$DUMP_FILE"
    continue
  fi

  echo "[OK ] Dump created: $DUMP_FILE"

  # Ротация — оставляем последние $RETENTION файлов
  echo "[INFO] Rotating, keep last $RETENTION for $DB_NAME"
  ls -1t "$DB_DIR"/*.dump 2>/dev/null | tail -n +$((RETENTION+1)) | while read -r old; do
    echo "[DEL] $old"
    rm -f "$old"
  done
done

echo "====== [$TS] DONE BACKUP ======"
