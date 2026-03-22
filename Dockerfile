FROM codercom/code-server:latest

USER root

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
    nixpkgs#repgrep \
    nixpkgs#gh

RUN apt update && apt install -y \
  iputils-ping \
  net-tools \
  dnsutils \
  curl \
  jq \
  wget \
  fzf \
  tmux \
  tree \
  ripgrep \
  traceroute \
  iproute2 \
  netcat-openbsd \
  tcpdump \
  zoxide \
  golang \
  host \
  ruby \
  sed \
  build-essential \
  whois

ENV NPM_CONFIG_PREFIX=/usr/local
RUN npm install -g \
    opencode-ai \
    @anthropic-ai/claude-code \
    @openai/codex

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

RUN curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# Install a system-wide profile script so every bash/sh session gets Nix
# on $PATH. This survives the /home/coder volume mount overwriting ~/.bashrc.
RUN echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' > /etc/profile.d/nix.sh

COPY entrypoint.sh /usr/bin/entrypoint.sh

USER 1000
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
