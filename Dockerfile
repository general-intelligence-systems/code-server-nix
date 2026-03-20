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
    nixpkgs#nodejs_22 \
    nixpkgs#ruby_3_4

# Install AI coding agents via npm (node is now on PATH from Nix).
RUN npm install -g \
    opencode-ai \
    @anthropic-ai/claude-code \
    @openai/codex

# Ensure coder user can use Nix.
RUN mkdir -p /home/coder/.nix-profile /home/coder/.nix-defexpr \
  && chown -R coder:coder /home/coder/.nix-profile /home/coder/.nix-defexpr

COPY entrypoint.sh /usr/bin/entrypoint.sh

USER 1000
ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "."]
