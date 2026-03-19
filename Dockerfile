FROM codercom/code-server:latest

USER root

# yq is not in Debian repos.
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

# Install Nix (single-user mode, no daemon — appropriate for containers).
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --extra-conf "sandbox = false" \
    --init none \
    --no-confirm
RUN mkdir -p /etc/nix \
  && printf "experimental-features = nix-command flakes\ntrusted-users = root coder\n" >> /etc/nix/nix.conf
RUN mkdir -p /home/coder/.nix-profile /home/coder/.nix-defexpr \
  && chown -R coder:coder /home/coder/.nix-profile /home/coder/.nix-defexpr

COPY entrypoint.sh /usr/bin/entrypoint.sh

USER 1000
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
