#!/bin/sh
# ══════════════════════════════════════════════════════════════
# Dev Container — Entrypoint Script
# ══════════════════════════════════════════════════════════════
# Executa configurações privilegiadas via sudo e depois roda
# o comando passado como argumento (CMD do Docker).
# ══════════════════════════════════════════════════════════════

set -e

# ── Configurações privilegiadas (via sudo — requer NOPASSWD) ──

# inotify: vital para Hot Reload (HMR) do Node.js
sudo sysctl -w fs.inotify.max_user_watches=524288  > /dev/null 2>&1 || true
sudo sysctl -w fs.inotify.max_user_instances=1024  > /dev/null 2>&1 || true

# Permissões do workspace
sudo chown -R devuser:devuser /workspace 2>/dev/null || true

# Docker socket: permite devuser usar Docker CLI
if [ -e /var/run/docker.sock ]; then
  sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# ── Executar o CMD passado pelo Docker ──
exec "$@"
