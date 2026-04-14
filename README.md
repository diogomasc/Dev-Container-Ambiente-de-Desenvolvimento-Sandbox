# Dev Container - Ambiente de Desenvolvimento Sandbox

> Container de desenvolvimento seguro e isolado para **Node.js**, **Python**, **Jupyter Notebook** e **treinamento de IA (CPU)**.
> Projetado para uso com **VS Code Remote Containers** — todos os runtimes ficam dentro do container.

---

## Índice

1. [Stack](#stack)
2. [Hardware de Referência](#hardware-de-referência)
3. [Pré-requisitos](#pré-requisitos)
4. [Instalação e Primeiro Uso](#instalação-e-primeiro-uso)
5. [Uso Diário](#uso-diário)
6. [VS Code — Conectar ao Container](#vs-code--conectar-ao-container)
7. [Jupyter Notebook](#jupyter-notebook)
8. [Docker dentro do Container](#docker-dentro-do-container)
9. [Treinamento de IA (CPU)](#treinamento-de-ia-cpu)
10. [Estrutura de Arquivos](#estrutura-de-arquivos)
11. [Limites de Recursos](#limites-de-recursos)
12. [Segurança](#segurança)
13. [Verificação e Diagnóstico](#verificação-e-diagnóstico)
14. [Comandos Úteis](#comandos-úteis)
15. [Trade-offs Documentados](#trade-offs-documentados)
16. [Troubleshooting](#troubleshooting)

---

## Stack

| Componente   | Versão / Ferramenta                                  | Propósito                                 |
| ------------ | ---------------------------------------------------- | ----------------------------------------- |
| **OS**       | Ubuntu 24.04 (minimal)                               | Imagem base estável                       |
| **Node.js**  | 22 LTS via [fnm](https://github.com/Schniz/fnm)      | Runtime JavaScript                        |
| **Python**   | 3.x (system) + [uv](https://github.com/astral-sh/uv) | Runtime Python + gerenciador ultra-rápido |
| **Jupyter**  | via `uv tool`                                        | Notebooks interativos                     |
| **Docker**   | CLI + Compose plugin (socket mount)                  | Gerenciar containers a partir de dentro   |
| **OpenBLAS** | libopenblas-dev                                      | Álgebra linear acelerada (NumPy/PyTorch)  |
| **Shell**    | Bash + [Starship](https://starship.rs)               | Prompt informativo e leve                 |
| **Git**      | Pré-configurado (nome, email, branch)                | Controle de versão                        |

---

## Hardware de Referência

Este container foi dimensionado para o seguinte hardware:

| Componente  | Especificação                                         |
| ----------- | ----------------------------------------------------- |
| **CPU**     | Intel i7-1255U (10 cores / 12 threads, 4.7 GHz boost) |
| **RAM**     | 32 GB DDR4 3200 MHz (2×16 GB)                         |
| **GPU**     | Intel Iris Xe (iGPU) — **sem GPU discreta**           |
| **Disco**   | 1 TB NVMe (Crucial P3 Plus)                           |
| **OS Host** | Ubuntu 24.04.4 LTS (Kernel 6.17)                      |

> ⚠️ **Sem NVIDIA GPU**: Treinamento de modelos será **CPU-bound**. O container inclui OpenBLAS para
> aceleração via instruções AVX2 do i7-1255U. Para modelos grandes, considere usar serviços de cloud GPU.

---

## Pré-requisitos

Antes de usar o container, você precisa ter instalado no **host** (sua máquina):

### 1. Docker Engine

Verifique se o Docker está instalado:

```bash
docker --version
```

Se não estiver, instale via [documentação oficial](https://docs.docker.com/engine/install/ubuntu/) ou:

```bash
# Instalar Docker Engine no Ubuntu
# Adicionar chave GPG oficial do Docker:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Adicionar repositório oficial do Docker:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Atualizar apt e instalar Docker
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2. Permissão Docker sem sudo

Para rodar `docker` sem `sudo` (necessário para o `docker compose`):

```bash
sudo usermod -aG docker $USER
```

> ⚠️ **Importante**: Após executar este comando, **reinicie a sessão** (logout/login) ou execute `newgrp docker` para que a permissão seja aplicada. Este passo é necessário **apenas uma vez**.

Verifique que funciona:

```bash
docker run --rm hello-world
```

### 3. VS Code (opcional, recomendado)

Instale a extensão [**Dev Containers**](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers):

```bash
code --install-extension ms-vscode-remote.remote-containers --force
```

---

## Instalação e Primeiro Uso

Clone o repositório e construa a imagem:

```bash
# 1. Clone o repositório
git clone https://github.com/diogomasc/Dev-Container-Ambiente-de-Desenvolvimento-Sandbox.git dev-container
cd dev-container

# 2. Construa a imagem (primeira vez — ~5-10 minutos)
docker compose build

# 3. Inicie o container
docker compose up -d
```

> 💡 O `docker compose up -d` cuida de tudo: **build** (se necessário) + **start**. Na primeira vez,
> ele faz o build automaticamente. Nos usos seguintes, ele só inicia o container existente.

### Comando único (build + start)

Se a imagem ainda não foi construída, o compose faz o build automaticamente:

```bash
docker compose up -d
```

Se você alterou o Dockerfile e quer **forçar a reconstrução**:

```bash
docker compose up -d --build
```

---

## Uso Diário

No dia a dia, os únicos comandos necessários são:

| Ação                 | Comando                        |
| -------------------- | ------------------------------ |
| **Iniciar**          | `docker compose up -d`         |
| **Parar**            | `docker compose down`          |
| **Reiniciar**        | `docker compose restart`       |
| **Acessar terminal** | `docker compose exec dev bash` |
| **Ver logs**         | `docker compose logs -f dev`   |
| **Ver status**       | `docker compose ps`            |
| **Verificar saúde**  | `docker stats --no-stream`     |

---

## VS Code — Conectar ao Container

### Método 1: Remote Containers (recomendado)

1. Abra o VS Code
2. Pressione `Ctrl+Shift+P` (Command Palette)
3. Digite e selecione **Dev Containers: Attach to Running Container**
4. Escolha **dev-container**
5. O VS Code abrirá uma nova janela conectada ao container

> 💡 O terminal integrado do VS Code já estará dentro do container, com Node, Python, Docker e Starship funcionando.

### Método 2: Terminal direto

```bash
docker compose exec dev bash
```

---

## Jupyter Notebook

O JupyterLab está pré-instalado via `uv tool install jupyterlab`. A interface é o **JupyterLab** (sucessor do Jupyter Notebook clássico).

> ⚠️ **Nota**: O binário disponível é `jupyter-lab`, não `jupyter notebook`.

### Iniciar o servidor

**De fora do container** (modo interativo — token aparece no terminal):

```bash
docker compose exec dev bash -c "jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser"
```

**De fora do container** (modo background — libera o terminal):

```bash
docker compose exec -d dev bash -c "jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser"
```

**De dentro do container** (via VS Code ou `docker compose exec dev bash`):

```bash
jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser
```

### Obter o token de acesso

Se o servidor foi iniciado em modo background (`-d`), o token não aparece no terminal.
Use o comando abaixo para recuperá-lo:

```bash
# De fora do container
docker compose exec dev bash -c "jupyter-lab list"

# De dentro do container
jupyter-lab list
```

A saída mostrará algo como:

```
Currently running servers:
http://dev-container:8888/?token=abc123... :: /workspace
```

### Acessar no navegador

Copie a URL acima e substitua `dev-container` por `localhost`:

```
http://localhost:8888/?token=abc123...
```

Ou acesse `http://localhost:8888` e cole o token no campo "Password or token".

### Parar o servidor

```bash
# De fora do container
docker compose exec dev bash -c "jupyter-lab stop"
```

### Usar via VS Code

Instale a extensão [**Jupyter**](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) no VS Code conectado ao container para editar notebooks `.ipynb` diretamente no editor.

---

## Docker dentro do Container

O container inclui **Docker CLI + Compose plugin**, conectado ao daemon do host via socket mount. Isso significa que você pode gerenciar containers "irmãos" de dentro do dev-container:

```bash
# Dentro do container
docker ps                    # Listar containers rodando no host
docker images                # Listar imagens
docker compose --help        # Docker Compose disponível
docker build -t myapp .      # Construir imagens
docker run --rm alpine echo "Hello from inside!"
```

> ⚠️ **Não é Docker-in-Docker real** (daemon dentro de daemon). É **Docker-out-of-Docker**: o CLI
> dentro do container se comunica com o daemon Docker do **host** via `/var/run/docker.sock`.
> Isso é mais seguro, mais rápido e mais eficiente que Docker-in-Docker real.

---

## Treinamento de IA (CPU)

### Instalar frameworks

```bash
# Criar um virtualenv para o projeto
python3 -m venv .venv && source .venv/bin/activate

# PyTorch (CPU) — via uv para instalação ultra-rápida
uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Ou TensorFlow (CPU)
uv pip install tensorflow-cpu

# Pacotes comuns de data science
uv pip install numpy pandas scikit-learn matplotlib jupyter

# Verificar que OpenBLAS está sendo usado
python3 -c "import numpy; numpy.show_config()"
```

### Dicas de Performance para CPU

| Dica                          | Comando / Config                                |
| ----------------------------- | ----------------------------------------------- |
| Usar todos os threads         | `torch.set_num_threads(8)`                      |
| Monitorar uso de RAM          | `free -h` ou `docker stats` (fora do container) |
| Limitar workers do DataLoader | `DataLoader(..., num_workers=4)`                |
| Verificar AVX2 disponível     | `lscpu \| grep avx2`                            |
| Mixed precision (BFloat16)    | `torch.autocast('cpu', dtype=torch.bfloat16)`   |
| Limitar threads OpenBLAS      | `export OPENBLAS_NUM_THREADS=8`                 |

> 💡 O `shm_size: 4gb` no compose garante que o PyTorch DataLoader funcione com `num_workers > 0`
> sem o erro `bus error` causado pelo limite padrão de 64MB do Docker.

---

## Estrutura de Arquivos

```
dev-container/
├── Dockerfile                    # Definição da imagem
├── docker-compose.yml            # Orquestração do container
├── projects/                     # Montado em /workspace (seus projetos)
│   └── (seus projetos aqui)
└── README.md                     # Este arquivo
```

| Caminho no host | Caminho no container   | Descrição                       |
| --------------- | ---------------------- | ------------------------------- |
| `./projects/`   | `/workspace`           | Pasta de projetos (persistente) |
| Docker socket   | `/var/run/docker.sock` | Acesso ao daemon Docker do host |

> A pasta `projects/` é criada automaticamente pelo compose ao lado do `docker-compose.yml`.

---

## Limites de Recursos

Distribuição de recursos baseada no hardware (32 GB RAM, 12 threads):

| Recurso  | Host (reservado) | Container (limite) | Justificativa                                     |
| -------- | ---------------- | ------------------ | ------------------------------------------------- |
| **RAM**  | ~16 GB           | **16 GB**          | Margem para OS + desktop + browser                |
| **CPU**  | 4 threads        | **8 threads**      | Suficiente para compilações em background no host |
| **shm**  | —                | **4 GB**           | PyTorch DataLoader IPC (multiprocessing)          |
| **/tmp** | —                | **512 MB** (tmpfs) | Checkpoints temporários, serialização de modelos  |

### Ajustar limites

Edite o `docker-compose.yml` conforme a necessidade:

```yaml
# Para workloads mais pesados de IA (menos margem no host):
deploy:
  resources:
    limits:
      cpus: "10" # Usar quase todos os threads (host pode ficar lento)
      memory: 24G # Mais RAM para modelos grandes (deixar ~8G pro host)

shm_size: "8gb" # Aumentar se DataLoader der "bus error" com muitos workers
```

---

## Segurança

| Medida                 | Descrição                                                 |
| ---------------------- | --------------------------------------------------------- |
| **Non-root user**      | Container roda como `devuser` (UID 1000)                  |
| **No privileged mode** | Sem acesso irrestrito ao host kernel                      |
| **no-new-privileges**  | Impede escalação de privilégios via setuid/setgid         |
| **Docker via socket**  | CLI conecta ao daemon do host (sem Docker-in-Docker)      |
| **inotify tuning**     | Configurado no entrypoint (sem necessidade de privileged) |
| **npm security**       | `npm_config_ignore_scripts` configurável por projeto      |

---

## Verificação e Diagnóstico

Após `docker compose up -d`, verifique que tudo está funcionando:

```bash
# 1. Status do container (deve mostrar "Up" e "healthy")
docker compose ps

# 2. Versões de todas as ferramentas
docker compose exec dev bash -c "\
  echo '=== Node ===' && node --version && \
  echo '=== Python ===' && python3 --version && \
  echo '=== JupyterLab ===' && jupyter-lab --version && \
  echo '=== Docker CLI ===' && docker --version && \
  echo '=== Docker Compose ===' && docker compose version && \
  echo '=== Starship ===' && starship --version && \
  echo '=== Git ===' && git --version && \
  echo '=== uv ===' && uv --version"

# 3. Verificar OpenBLAS
docker compose exec dev bash -c "python3 -c \"import ctypes; lib=ctypes.CDLL('libopenblas.so'); print('✅ OpenBLAS OK')\""

# 4. Verificar Docker socket (deve listar containers do host)
docker compose exec dev docker ps

# 5. Limites de memória (deve mostrar 16GiB no MEM LIMIT)
docker stats --no-stream

# 6. Shared memory (deve mostrar ~4GB)
docker compose exec dev df -h /dev/shm
```

---

## Comandos Úteis

### Gerenciamento do container

```bash
# Reconstruir a imagem (após alterar Dockerfile)
docker compose up -d --build

# Reconstruir do zero (sem cache)
docker compose build --no-cache && docker compose up -d

# Parar e remover tudo (volumes persistem)
docker compose down

# Parar, remover e limpar volumes
docker compose down -v

# Ver uso de espaço em disco
docker system df
```

### Dentro do container

```bash
# Instalar pacote Node.js global
npm install -g <pacote>

# Criar virtualenv Python
python3 -m venv .venv && source .venv/bin/activate

# Instalar pacotes Python (ultra-rápido)
uv pip install <pacote>

# Trocar versão do Node
fnm install 20 && fnm use 20

# Listar versões do Node instaladas
fnm list

# Monitorar recursos em tempo real
top
```

---

## Trade-offs Documentados

| Decisão                            | Ganho                               | Custo                                   |
| ---------------------------------- | ----------------------------------- | --------------------------------------- |
| Bash + Starship vs Zsh + Oh-My-Zsh | ~30 MB menor, startup rápido        | Sem plugins Zsh (autosuggestions)       |
| fnm vs nvm                         | Startup 10-50x mais rápido (Rust)   | Menos adoção que nvm                    |
| uv vs pip                          | 10-100x mais rápido                 | API pode mudar                          |
| Docker CLI via socket vs DinD      | ~150 MB menor, mais seguro          | Containers são "irmãos", não filhos     |
| Node 22 LTS vs 24                  | Mais estável, suporte longo prazo   | Sem features bleeding-edge              |
| OpenBLAS vs MKL                    | Open source, ~20 MB                 | MKL é ~5% mais rápido em Intel          |
| 16 GB RAM para container           | Suficiente para maioria dos modelos | Host pode ficar lento sob carga extrema |

---

## Troubleshooting

### "permission denied" ao rodar `docker compose`

```bash
# Adicione seu usuário ao grupo docker (apenas uma vez, requer relogin)
sudo usermod -aG docker $USER
newgrp docker
```

### Container não sobe / erro no build

```bash
# Ver logs de build detalhados
docker compose build --no-cache --progress=plain

# Ver logs do container
docker compose logs dev
```

### "No space left on device"

```bash
# Limpar imagens/containers/volumes não usados
docker system prune -af --volumes
```

### Node.js HMR não detecta mudanças

O entrypoint já configura `inotify.max_user_watches=524288`. Se o problema persistir:

```bash
# Dentro do container, verificar o valor
cat /proc/sys/fs/inotify/max_user_watches  # deve ser 524288
```

### Jupyter não abre / token não aparece

Certifique-se de usar `jupyter-lab` (não `jupyter notebook`) e `--ip=0.0.0.0`:

```bash
# Iniciar (modo interativo — token aparece no terminal)
docker compose exec dev bash -c "jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser"

# Se iniciou em background (-d), recupere o token com:
docker compose exec dev bash -c "jupyter-lab list"
```

A porta 8888 deve estar mapeada no compose (já está por padrão).

### PyTorch DataLoader dá "bus error"

O `shm_size: 4gb` no compose deve resolver. Se persistir, aumente:

```yaml
shm_size: "8gb"
```

### Docker CLI dentro do container não funciona

Verifique se o socket está montado:

```bash
ls -la /var/run/docker.sock  # deve existir
docker ps                    # deve listar containers do host
```
