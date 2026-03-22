FROM codercom/code-server:latest

USER root

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install prerequisites
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    && mkdir -p /etc/apt/keyrings

# 2. Add the NodeSource GPG key
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# 3. Create the NodeSource repository for Node.js 24.x
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# 4. Update and install Node.js
RUN apt-get update && apt-get install -y nodejs

# Verify the installation
RUN node -v && npm -v

# Install Nix (Determinate Systems installer — multi-user, daemonless for build).
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --extra-conf "sandbox = false" \
    --extra-conf "filter-syscalls = false" \
    --init none \
    --no-confirm

ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

RUN mkdir -p /etc/nix \
  && printf "experimental-features = nix-command flakes\ntrusted-users = root coder\n" >> /etc/nix/nix.conf

# Install system tooling via Nix.
RUN nix profile install \
    nixpkgs#yq-go \
    nixpkgs#bat \
    nixpkgs#vim \
    nixpkgs#direnv \
    nixpkgs#ripgrep \
    nixpkgs#gh

RUN apt-get update && apt-get install -y \
  iputils-ping \
  net-tools \
  dnsutils \
  curl \
  jq \
  wget \
  fzf \
  tmux \
  tree \
  traceroute \
  iproute2 \
  netcat-openbsd \
  tcpdump \
  zoxide \
  golang \
  ruby \
  sed \
  build-essential \
  whois

ENV NPM_CONFIG_PREFIX=/usr/local
RUN npm install -g \
    opencode-ai \
    @anthropic-ai/claude-code \
    @openai/codex

# Install kubectl (arch-aware)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install docker-compose (arch-aware)
RUN ARCH=$(uname -m) && \
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Install a system-wide profile script so every bash/sh session gets Nix
# on $PATH. This survives the /home/coder volume mount overwriting ~/.bashrc.
RUN echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' > /etc/profile.d/nix.sh

COPY entrypoint.sh /usr/bin/entrypoint.sh

USER 1000
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
