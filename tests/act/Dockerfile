# act job image: non-root user so the Nix installer is not run as root.
# UID/GID default to 1000 to match a typical host bind-mount owner.
FROM ghcr.io/catthehacker/ubuntu:act-22.04

ARG USERNAME=runner
ARG UID=1000
ARG GID=1000

RUN if ! getent group "${GID}" >/dev/null; then groupadd --gid "${GID}" "${USERNAME}"; fi \
  && useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash "${USERNAME}" \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
  && mkdir -p /etc/udev/rules.d

ENV HOME=/home/runner \
    USER=runner
USER runner
WORKDIR /home/runner
RUN mkdir -p /home/runner/.cache/nix
