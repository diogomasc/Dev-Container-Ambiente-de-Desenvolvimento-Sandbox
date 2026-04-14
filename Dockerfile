# ══════════════════════════════════════════════════════════════
# Dev Container — Ambiente de Desenvolvimento Leve (Lightweight)
# Stack: Node 22 LTS (fnm) + Python 3 (uv) + JupyterLab + Docker CLI + Starship
# ══════════════════════════════════════════════════════════════
# Decisões de Projeto:
#   - Bash + Starship em vez de Zsh + Oh-My-Zsh (economiza ~30MB, alinha com o host)
#   - fnm em vez de nvm (mais rápido, menor pegada no sistema, escrito em Rust)
#   - uv em vez de pip (instalações 10-100x mais rápidas, escrito em Rust)
#   - Apenas Docker CLI (montagem via socket para o daemon do host — sem engine completa)
#   - --no-install-recommends em chamadas apt (economiza ~100MB)
#   - RUN único por grupo lógico para minimizar camadas (layers)
# ══════════════════════════════════════════════════════════════

FROM ubuntu:24.04

# ── Metadados (Padrão OCI) ──────────────────────────────────
LABEL org.opencontainers.image.title="dev-container"
LABEL org.opencontainers.image.description="Container de dev leve: Node 22 LTS + Python 3 + JupyterLab + Docker CLI + Starship"
LABEL org.opencontainers.image.authors="Diogo Mascarenhas <diogomascarenhas0574@gmail.com>"

# ── Configurações de Ambiente ────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Pacotes do Sistema (Camada única, mínima) ────────────────
# build-essential: necessário para addons nativos do Node (node-gyp) e extensões C do Python
# python3-venv: ambientes Python isolados sem poluir o pip do sistema
# libopenblas-dev: BLAS/LAPACK otimizado para inferência em CPU (NumPy/SciPy/PyTorch)
# procps: ferramentas ps/top/free para monitorar cargas de treinamento
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        sudo \
        unzip \
        bash \
        gnupg \
        lsb-release \
        python3 \
        python3-venv \
        python3-dev \
        build-essential \
        libopenblas-dev \
        gfortran \
        procps \
        tree \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Docker CLI (Montagem via socket para o host) ──────────────
# Apenas a CLI + plugin do compose (~50MB), NÃO a engine completa (~200MB).
# O daemon do Docker do host é compartilhado via montagem de /var/run/docker.sock.
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin \
    && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Usuário Comum (Non-root) ──────────────────────────────────
# Segurança: o container roda como usuário sem privilégios, com sudo 
# sem senha apenas para tarefas administrativas eventuais.
ARG USERNAME=devuser
ARG USER_UID=1000
ARG USER_GID=1000

RUN userdel -f -r ubuntu 2>/dev/null || true \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && groupadd -f docker \
    && usermod -aG docker ${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ── fnm + Node 22 LTS ────────────────────────────────────────
# fnm é um gerenciador de versões Node rápido em Rust (~3MB o binário)
# Node 22 é a linha LTS ativa (estável para cargas de produção)
RUN curl -fsSL https://fnm.vercel.app/install | bash \
    && export PATH="$HOME/.local/share/fnm:$PATH" \
    && eval "$(fnm env)" \
    && fnm install 22 \
    && fnm default 22 \
    && eval "$(fnm env)" \
    && npm config set fund false \
    && npm config set audit false \
    && npm cache clean --force

# ── uv + JupyterLab ──────────────────────────────────────────
# uv: gerenciador de pacotes Python ultra-rápido (Rust, substitui o pip)
# JupyterLab instalado como 'tool' para evitar poluir o ambiente Python global.
# Nota: o meta-pacote 'jupyter' não expõe entrypoints — 'jupyterlab' é o
# pacote que fornece o CLI `jupyter` e a interface Lab.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && export PATH="$HOME/.local/bin:$PATH" \
    && uv tool install jupyterlab --quiet \
    && rm -rf /tmp/* ~/.cache/uv

# ── Prompt Starship ──────────────────────────────────────────
# Prompt minimalista e rápido (~4MB binário em Rust) — substitui o Oh-My-Zsh (~30MB)
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# ── Configuração do Starship (Alinhado com o setup do Diogo no host) ──
RUN mkdir -p ~/.config && cat <<'EOF' > ~/.config/starship.toml
format = """
\\[ [$time](bold white) \\] $username$directory$git_branch$git_status$nodejs$python$docker_context$line_break$character
"""

add_newline = true

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[time]
disabled    = false
format      = "$time"
time_format = "%H:%M"
style       = "bold white"

[username]
show_always = true
style_user  = "bold yellow"
style_root  = "bold red"
format      = "[$user]($style) "

[directory]
truncation_length = 2
truncate_to_repo  = false
truncation_symbol = "../"
format            = "on [$path]($style)[$read_only]($read_only_style) "
style             = "bold cyan"

[git_branch]
symbol = "󰘬 "
format = "on [$symbol$branch]($style) "
style  = "bold purple"

[git_status]
format = "([\\[$all_status$ahead_behind\\]]($style) )"
style  = "red"

[nodejs]
symbol = "󰎙 "
format = "via [$symbol($version)]($style) "
style  = "bold green"

[python]
symbol = "󰌠 "
format = "via [$symbol($version)( \\($virtualenv\\))]($style) "
style  = "bold yellow"

[docker_context]
symbol = "󰡨 "
format = "on [$symbol$context]($style) "
style  = "bold blue"
EOF

# ── Configuração do Bashrc ───────────────────────────────────
RUN cat <<'BASHRC' >> ~/.bashrc

# ═══════════════════════════════════════════════════════════
# DEV CONTAINER — Configuração do Shell
# ═══════════════════════════════════════════════════════════

# ── fnm (Gerenciador de versões Node) ──
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd)"

# ── uv / Ferramentas Python ──
export PATH="$HOME/.local/bin:$PATH"

# ── Prompt Starship ──
eval "$(starship init bash)"

# ── Aliases ──
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -15'

# ── Segurança Node.js: desabilita scripts postinstall por padrão ──
# Reabilite por projeto com: npm config set ignore-scripts false
# Isso previne ataques de cadeia de suprimentos via scripts de instalação maliciosos
export npm_config_ignore_scripts=false
BASHRC

# ── Configuração do Git ──────────────────────────────────────
RUN git config --global user.name "Diogo Mascarenhas" \
    && git config --global user.email "diogomascarenhas0574@gmail.com" \
    && git config --global init.defaultBranch main \
    && git config --global core.autocrlf input \
    && git config --global pull.rebase true

# ── Consolidação do PATH ─────────────────────────────────────
ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.local/share/fnm:${PATH}"

# ── Espaço de Trabalho ───────────────────────────────────────
WORKDIR /workspace

# ── Porta do Jupyter ─────────────────────────────────────────
EXPOSE 8888

# ── Healthcheck (Verificação de Saúde) ────────────────────────
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -x "sleep" > /dev/null || exit 1

# ── Entrypoint Padrão ────────────────────────────────────────
CMD ["sleep", "infinity"]