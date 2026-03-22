#!/bin/sh
set -eu

# Lock in system PATH before anything can clobber it.
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH="${SYSTEM_PATH}:${PATH}"

# We do this first to ensure sudo works below when renaming the user.
# Otherwise the current container UID may not exist in the passwd database.
eval "$(fixuid -q)"
# Restore Nix store if the mount shadowed it
if [ ! -e /nix/var/nix/profiles/default/bin/nix ]; then
  sudo cp -a /nix-store-backup/* /nix/
fi

if [ "${DOCKER_USER-}" ]; then
  USER="$DOCKER_USER"
  if [ -z "$(id -u "$DOCKER_USER" 2>/dev/null)" ]; then
    echo "$DOCKER_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd > /dev/null
    # Unfortunately we cannot change $HOME as we cannot move any bind mounts
    # nor can we bind mount $HOME into a new home as that requires a privileged container.
    sudo usermod --login "$DOCKER_USER" coder
    sudo groupmod -n "$DOCKER_USER" coder

    sudo sed -i "/coder/d" /etc/sudoers.d/nopasswd
  fi
fi

# Purge stale user-level Nix profile state left on the PVC from a
# previous image build. The symlink targets live in the (ephemeral)
# Nix store, so after a rebuild they dangle and nix-daemon.sh chokes.
for p in "$HOME/.nix-profile" "$HOME/.nix-defexpr" "$HOME/.nix-channels"; do
  if [ -L "$p" ] && [ ! -e "$p" ]; then
    rm -f "$p"    # broken symlink
  elif [ -e "$p" ] && [ ! -d "$p" ]; then
    rm -f "$p"    # regular file blocking mkdir
  fi
done

# Source Nix profile so that nix, nix-shell, nix-build, etc. are on $PATH
# for code-server terminal sessions.
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Re-assert system PATH in case the sourced script replaced it.
case ":${PATH}:" in
  *":/usr/bin:"*) ;;
  *) export PATH="${PATH}:${SYSTEM_PATH}" ;;
esac

# Start the Nix daemon (multi-user install requires it at runtime).
if [ -e '/nix/var/nix/profiles/default/bin/nix-daemon' ]; then
  sudo /nix/var/nix/profiles/default/bin/nix-daemon &
fi

# Allow users to have scripts run on container startup to prepare workspace.
# https://github.com/coder/code-server/issues/5177
if [ -d "${ENTRYPOINTD}" ]; then
  find "${ENTRYPOINTD}" -type f -executable -print -exec {} \;
fi

exec dumb-init /usr/bin/code-server "$@"
