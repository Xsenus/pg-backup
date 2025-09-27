
# 🧰 PostgreSQL Multi-Database Backup Service

Надёжный сервис для ежедневного резервного копирования нескольких PostgreSQL баз данных с ротацией, логированием и автодеплоем через GitHub Actions на VPS.

---

## ⚙️ Возможности

- 📅 Ежедневный автоматический бэкап всех указанных БД (через `systemd timer`)
- ♻️ Ротация — хранение заданного количества копий (по умолчанию 10)
- 📂 Архивы в формате `pg_dump -Fc` с компрессией `-Z9`
- 🧪 Проверка целостности (`pg_restore -l`)
- 🧾 Логирование в journald и файлы `/var/log/pg-multi-backup/backup-YYYY-MM.log`
- 🚀 Автодеплой на VPS через GitHub Actions без Docker
- 🛠️ Утилита восстановления (`restore.sh`)
- 🔐 Конфигурация через `.env` (секреты не хранятся в репозитории)

---

## 📁 Структура проекта

```bash
pg-backup/
├─ scripts/
│  ├─ backup.sh              # Основной скрипт бэкапа
│  ├─ restore.sh             # Скрипт восстановления
│  └─ install_systemd.sh     # Установка systemd юнитов
├─ systemd/
│  ├─ pg-multi-backup.service
│  └─ pg-multi-backup.timer
├─ .env.example
├─ .gitignore
└─ .github/
   └─ workflows/
      └─ deploy-backup.yml   # Автодеплой через GitHub Actions
```

---

## 🔧 Установка вручную на VPS

### 1. Установить `postgresql-client` (если нет)

```bash
sudo apt update && sudo apt install -y postgresql-client
```

### 2. Скопировать проект на VPS

```bash
sudo mkdir -p /opt/pg-backup
cd /opt/pg-backup
# скопируйте файлы проекта (scp / git clone)
```

### 3. Создать конфигурацию `/etc/pg-multi-backup.env`

```bash
sudo nano /etc/pg-multi-backup.env
```

Пример содержимого:

```dotenv
BACKUP_ROOT=/opt/pg-backups
RETENTION=10
LOG_DIR=/var/log/pg-multi-backup
PG_DUMP_OPTS="--no-owner --no-privileges -Z9"

MAIN_DATABASE_URL=postgresql+asyncpg://admin:PASS@127.0.0.1:5464/base
BITRIX_DATABASE_URL=postgresql+asyncpg://admin:PASS@127.0.0.1:5464/base
PARSING_DATABASE_URL=postgresql+asyncpg://admin:PASS@127.0.0.1:5464/base
PP719_DATABASE_URL=postgresql+asyncpg://admin:PASS@127.0.0.1:5464/base
```

### 4. Установить systemd-юниты

```bash
chmod +x scripts/*.sh
sudo scripts/install_systemd.sh
```

Проверить:

```bash
systemctl list-timers --all | grep pg-multi
```

### 5. Тестовый запуск

```bash
sudo systemctl start pg-multi-backup.service
sudo journalctl -u pg-multi-backup.service -n 50 --no-pager
```

Результаты: `/opt/pg-backups/<db_name>/*.dump`

---

## 🚀 Автодеплой через GitHub Actions

### 1. Настройте секреты в GitHub → Settings → Secrets → Actions

| Название | Описание |
|----------|-----------|
| `VPS_HOST` | IP адрес вашего VPS (например, `127.0.0.1`) |
| `VPS_USER` | Пользователь для SSH (например, `root`) |
| `VPS_SSH_KEY` | Приватный ключ SSH |
| `PG_BACKUP_ENV` | Содержимое файла `/etc/pg-multi-backup.env` |

### 2. При каждом push в `main`

- Репозиторий заливается на VPS в `/opt/pg-backup`
- Создаётся/обновляется `/etc/pg-multi-backup.env`
- Устанавливаются юниты
- Выполняется тестовый бэкап

---

## 📜 Логи и отладка

Просмотреть логи последнего запуска:

```bash
sudo journalctl -u pg-multi-backup.service -n 50 --no-pager
```

Логи по месяцам:

```bash
cat /var/log/pg-multi-backup/backup-2025-09.log
```

---

## ♻️ Ротация

Для каждой базы хранится максимум `RETENTION` копий. Старые удаляются автоматически:

```bash
/opt/pg-backups/postgres/postgres__2025-09-27_02-30-05.dump
```

---

## 🔁 Восстановление

```bash
/opt/pg-backup/scripts/restore.sh \
  /opt/pg-backups/postgres/postgres__2025-09-27_02-30-05.dump \
  "postgresql://admin:PASS@79.174.94.14:5464/postgres"
```

---

## 🧪 Проверка целостности дампов

```bash
pg_restore -l /opt/pg-backups/postgres__*.dump | head
```

---

## 🧰 Команды управления

| Команда | Назначение |
|---------|-------------|
| `sudo systemctl start pg-multi-backup.service` | Запустить вручную |
| `sudo systemctl status pg-multi-backup.service` | Проверить статус |
| `sudo systemctl list-timers` | Список таймеров |
| `sudo systemctl start pg-multi-backup.timer` | Включить таймер |
| `sudo systemctl stop pg-multi-backup.timer` | Остановить таймер |

---

## 🛠️ Советы

- Для больших БД можно вынести `/opt/pg-backups` на отдельный диск.
- Для оповещений можно подключить Telegram-бот или email.
- Можно добавить `logrotate` для месячных логов, если файл растёт.

---

## 📄 Лицензия

MIT License © 2025
