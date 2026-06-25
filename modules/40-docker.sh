#!/usr/bin/env bash
# 40-docker.sh — Docker Engine + Compose plugin (Linux) / Docker Desktop (macOS).

ui_section "Docker"

install_docker_debian() {
  # Official Docker convenience repository.
  maybe_sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | maybe_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  maybe_sudo chmod a+r /etc/apt/keyrings/docker.gpg

  local codename arch
  arch="$(dpkg --print-architecture)"
  # shellcheck disable=SC1091  # /etc/os-release only exists on the target Linux host
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-stable}")"
  echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
    | maybe_sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

case "$DOTFILES_OS" in
  debian)
    if has docker; then
      ui_skip "docker already installed ($(docker --version 2>/dev/null))"
    else
      ui_run "Install Docker Engine" install_docker_debian
    fi
    # Add the current user to the docker group for rootless-ish usage.
    if ! id -nG "$USER" 2>/dev/null | grep -qw docker; then
      ui_run "Add $USER to docker group" maybe_sudo usermod -aG docker "$USER"
      ui_warn "Log out and back in for docker group membership to take effect."
    fi
    maybe_sudo systemctl enable --now docker 2>/dev/null || true
    ;;
  macos)
    if has docker; then
      ui_skip "docker already installed"
    elif ui_confirm "Install Docker Desktop (cask)?" Y; then
      ui_run "Install Docker Desktop" brew install --cask docker \
        || ui_warn "Could not install Docker Desktop; install it manually from docker.com"
    else
      ui_info "Skipping Docker Desktop. Install later with: brew install --cask docker"
    fi
    ;;
esac
