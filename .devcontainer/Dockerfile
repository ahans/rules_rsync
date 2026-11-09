FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=ubuntu

# Base tools + what Bazel typically needs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git sudo less \
        build-essential python3 unzip vim zip \
    && rm -rf /var/lib/apt/lists/*

# Claude Code (Anthropic's signed apt repo, stable channel)
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
        > /etc/apt/sources.list.d/claude-code.list \
    && apt-get update && apt-get install -y --no-install-recommends claude-code \
    && rm -rf /var/lib/apt/lists/*

# uv / uvx
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Bazelisk, also available as `bazel`
RUN ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL -o /usr/local/bin/bazelisk \
        "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${ARCH}" \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s bazelisk /usr/local/bin/bazel

# Default 'ubuntu' user (UID 1000): passwordless sudo, pre-created dirs so
# named volumes mounted there inherit the user's ownership
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /home/${USERNAME}/.claude /home/${USERNAME}/.cache/bazel /home/${USERNAME}/.cache/uv \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Keep all Claude Code state (incl. .claude.json) in one persistable dir
ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude

USER ${USERNAME}
WORKDIR /home/${USERNAME}
