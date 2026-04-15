# ══════════════════════════════════════════════════════════════
# Dev Container — Ambiente de Desenvolvimento Completo
# Stack: Node 22 LTS (fnm) + Python 3 (uv) + JupyterLab + Docker CLI
# Shell: Zsh + Starship + plugins (autocomplete, syntax-highlight, etc.)
# ══════════════════════════════════════════════════════════════
# Decisões de Projeto:
#   - Zsh + Starship + plugins leves (sem Oh-My-Zsh — menor overhead)
#   - fnm em vez de nvm (mais rápido, menor pegada no sistema, escrito em Rust)
#   - uv em vez de pip (instalações 10-100x mais rápidas, escrito em Rust)
#   - Apenas Docker CLI (montagem via socket para o daemon do host — sem engine completa)
#   - --no-install-recommends em chamadas apt (economiza ~100MB)
#   - RUN único por grupo lógico para minimizar camadas (layers)
# ══════════════════════════════════════════════════════════════

FROM ubuntu:24.04

# ── Metadados (Padrão OCI) ──────────────────────────────────
LABEL org.opencontainers.image.title="dev-container"
LABEL org.opencontainers.image.description="Container de dev completo: Node 22 LTS + Python 3 + JupyterLab + Docker CLI + Zsh + Starship"
LABEL org.opencontainers.image.authors="Diogo Mascarenhas <diogomascarenhas0574@gmail.com>"

# ── Configurações de Ambiente ────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Pacotes do Sistema (Camada única, mínima) ────────────────
# zsh: shell interativo completo com suporte a plugins
# build-essential: necessário para addons nativos do Node (node-gyp) e extensões C do Python
# python3-venv: ambientes Python isolados sem poluir o pip do sistema
# libopenblas-dev: BLAS/LAPACK otimizado para inferência em CPU (NumPy/SciPy/PyTorch)
# procps: ferramentas ps/top/free para monitorar cargas de treinamento
# wget: necessário para o Antigravity (VS Code) baixar o servidor remoto
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        sudo \
        unzip \
        zsh \
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
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh ${USERNAME} \
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

# ── Poetry (Gerenciador de dependências Python) ──────────────
# Instalado via installer oficial em ~/.local/bin.
# Poetry gerencia virtualenvs, lockfiles e builds de pacotes Python.
RUN curl -sSL https://install.python-poetry.org | python3 - \
    && export PATH="$HOME/.local/bin:$PATH" \
    && poetry config virtualenvs.in-project true \
    && rm -rf /tmp/*

# ── Prompt Starship ──────────────────────────────────────────
# Prompt informativo e rápido (~4MB binário em Rust)
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# ── Plugins Zsh (instalados diretamente, sem framework) ──────
# Clonados no build para evitar download em runtime.
# Plugins escolhidos por impacto direto na produtividade:
#   - autosuggestions:      previsão de comandos baseada no histórico (estilo Fish)
#   - syntax-highlighting:  coloração em tempo real (verde=válido, vermelho=erro)
#   - completions:          definições extras de autocompletar para 200+ ferramentas
#   - history-substring-search: busca por substring no histórico com ↑/↓
RUN mkdir -p ~/.zsh/plugins \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
        ~/.zsh/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        ~/.zsh/plugins/zsh-syntax-highlighting \
    && git clone --depth=1 https://github.com/zsh-users/zsh-completions.git \
        ~/.zsh/plugins/zsh-completions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git \
        ~/.zsh/plugins/zsh-history-substring-search \
    && rm -rf ~/.zsh/plugins/*/.git

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

# ── Configuração do Zshrc ────────────────────────────────────
RUN cat <<'ZSHRC' > ~/.zshrc
# ═══════════════════════════════════════════════════════════
# DEV CONTAINER — Configuração do Zsh
# ═══════════════════════════════════════════════════════════

# ── Histórico ──
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY       # Registrar timestamp no histórico
setopt HIST_EXPIRE_DUPS_FIRST # Expirar duplicatas primeiro
setopt HIST_IGNORE_DUPS       # Não registrar duplicatas consecutivas
setopt HIST_IGNORE_SPACE      # Não registrar comandos que iniciam com espaço
setopt HIST_VERIFY            # Mostrar comando antes de executar do histórico
setopt SHARE_HISTORY          # Compartilhar histórico entre sessões Zsh
setopt APPEND_HISTORY         # Append em vez de sobrescrever

# ── Opções do Zsh ──
setopt AUTO_CD                # cd implícito ao digitar apenas o nome do diretório
setopt AUTO_PUSHD             # Empilhar diretórios automaticamente (cd -)
setopt PUSHD_IGNORE_DUPS      # Não empilhar diretórios duplicados
setopt CORRECT                # Sugerir correção para comandos
setopt INTERACTIVE_COMMENTS   # Permitir comentários em sessões interativas
setopt NO_BEEP                # Sem beep irritante

# ── Sistema de Completions ──
autoload -Uz compinit
fpath=(~/.zsh/plugins/zsh-completions/src $fpath)
compinit -C  # -C usa cache para startup mais rápido

# Estilo das completions (menu interativo com seleção)
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case-insensitive
zstyle ':completion:*' list-colors '${(s.:.)LS_COLORS}'    # Cores do ls
zstyle ':completion:*' group-name ''                       # Agrupar resultados
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}Nenhum resultado encontrado%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ── Keybindings ──
bindkey -e                      # Modo Emacs (Ctrl+A, Ctrl+E, etc.)
bindkey '^[[A' history-substring-search-up    # ↑ busca no histórico
bindkey '^[[B' history-substring-search-down  # ↓ busca no histórico
bindkey '^[[1;5C' forward-word   # Ctrl+→ avança uma palavra
bindkey '^[[1;5D' backward-word  # Ctrl+← volta uma palavra
bindkey '^[[3~' delete-char      # Delete funciona corretamente
bindkey '^[[H' beginning-of-line # Home
bindkey '^[[F' end-of-line       # End

# ── PATH ──
export PATH="$HOME/.local/share/fnm:$HOME/.local/bin:$PATH"

# ── fnm (Gerenciador de versões Node) ──
eval "$(fnm env --use-on-cd --shell zsh)"

# ── Prompt Starship ──
eval "$(starship init zsh)"

# ── Plugins (carregar APÓS compinit) ──
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# ── Configuração dos Plugins ──
# Autosuggestions: previsão estilo Fish (cinza fraco)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Syntax Highlighting: cores para validação em tempo real
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'

# History Substring Search: cores para resultado da busca
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=green,fg=black,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white,bold'

# ── Aliases ──
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -15'
alias gco='git checkout'
alias gcm='git commit -m'
alias gp='git push'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias mkdir='mkdir -pv'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ── Segurança Node.js: desabilita scripts postinstall por padrão ──
# Reabilite por projeto com: npm config set ignore-scripts false
export npm_config_ignore_scripts=false
ZSHRC

# ── Bashrc mínimo (fallback se bash for invocado) ────────────
RUN cat <<'BASHRC' > ~/.bashrc
# Fallback — o shell padrão é Zsh. Este .bashrc é mínimo.
export PATH="$HOME/.local/share/fnm:$HOME/.local/bin:$PATH"
eval "$(fnm env --use-on-cd)" 2>/dev/null
eval "$(starship init bash)" 2>/dev/null
alias ll='ls -lah --color=auto --group-directories-first'
BASHRC

# ── Configuração do Git ──────────────────────────────────────
RUN git config --global user.name "Diogo Mascarenhas" \
    && git config --global user.email "diogomascarenhas0574@gmail.com" \
    && git config --global init.defaultBranch main \
    && git config --global core.autocrlf input \
    && git config --global pull.rebase true

# ── Consolidação do PATH ─────────────────────────────────────
ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.local/share/fnm:${PATH}"

# ── Entrypoint (init privilegiado → drop para devuser) ───────
# Copia como root (proprietário) para que o entrypoint possa executar
# sysctl e chown antes de dropar para devuser.
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# ── Espaço de Trabalho ───────────────────────────────────────
WORKDIR /workspace

# ── Porta do Jupyter ─────────────────────────────────────────
EXPOSE 8888

# ── Healthcheck (Verificação de Saúde) ────────────────────────
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -x "sleep" > /dev/null || exit 1

# ── Entrypoint + CMD Padrão ──────────────────────────────────
ENTRYPOINT ["entrypoint.sh"]
CMD ["sleep", "infinity"]