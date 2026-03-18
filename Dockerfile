# syntax=docker/dockerfile:experimental

ARG BASE=debian:12
FROM scratch AS packages
COPY release-packages/code-server*.deb /tmp/

FROM $BASE

RUN apt-get update \
  && apt-get install -y \
    curl \
    dumb-init \
    git \
    git-lfs \
    htop \
    jq \
    locales \
    lsb-release \
    man-db \
    nano \
    openssh-client \
    procps \
    ruby \
    sudo \
    vim-tiny \
    wget \
    xz-utils \
    zsh \
  && git lfs install \
  && rm -rf /var/lib/apt/lists/*

# yq is not in Debian repos — install from GitHub releases.
RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq

# Install Node.js (needed for npm-based CLI tools below).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Install AI coding agents.
RUN npm install -g \
    opencode-ai \
    @anthropic-ai/claude-code \
    @openai/codex

# https://wiki.debian.org/Locale#Manually
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8

RUN if grep -q 1000 /etc/passwd; then \
    userdel -r "$(id -un 1000)"; \
  fi \
  && adduser --gecos '' --disabled-password coder \
  && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - \
  && chown root:root /usr/local/bin/fixuid \
  && chmod 4755 /usr/local/bin/fixuid \
  && mkdir -p /etc/fixuid \
  && printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

# Install Nix (single-user mode, no daemon — appropriate for containers).
# Uses the Determinate Systems installer for a clean, non-interactive install.
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --extra-conf "sandbox = false" \
    --init none \
    --no-confirm
# Enable flakes and the unified nix CLI, trust the coder user for binary caches.
RUN mkdir -p /etc/nix \
  && printf "experimental-features = nix-command flakes\ntrusted-users = root coder\n" >> /etc/nix/nix.conf
# Ensure the coder user has a Nix profile and owns the relevant directories.
RUN mkdir -p /home/coder/.nix-profile /home/coder/.nix-defexpr \
  && chown -R coder:coder /home/coder/.nix-profile /home/coder/.nix-defexpr

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN --mount=from=packages,src=/tmp,dst=/tmp/packages dpkg -i /tmp/packages/code-server*$(dpkg --print-architecture).deb

# Allow users to have scripts run on container startup to prepare workspace.
# https://github.com/coder/code-server/issues/5177
ENV ENTRYPOINTD=${HOME}/entrypoint.d

EXPOSE 8080
# This way, if someone sets $DOCKER_USER, docker-exec will still work as
# the uid will remain the same. note: only relevant if -u isn't passed to
# docker-run.
USER 1000
ENV USER=coder
WORKDIR /home/coder
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
