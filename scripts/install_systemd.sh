#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/opt/pg-backup"

install -Dm644 "$REPO_DIR/systemd/pg-multi-backup.service" /etc/systemd/system/pg-multi-backup.service
install -Dm644 "$REPO_DIR/systemd/pg-multi-backup.timer"   /etc/systemd/system/pg-multi-backup.timer

systemctl daemon-reload
systemctl enable pg-multi-backup.timer
systemctl start pg-multi-backup.timer

echo "[OK] systemd timer enabled. To run now: systemctl start pg-multi-backup.service"
