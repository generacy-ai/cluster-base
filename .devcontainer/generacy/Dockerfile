# Generacy Development Cluster
# Multi-stage build for efficient layer caching
#
# Customize this Dockerfile for your project's needs.
# The stages are structured so that infrequently-changing layers
# (system packages, CLIs) are cached separately from the tooling layer.

# -- Stage 1: System dependencies (rarely changes, caches well) ---------------
FROM mcr.microsoft.com/devcontainers/typescript-node:22-bookworm AS base

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg netcat-openbsd redis-tools \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# -- Stage 2: Generacy tooling (changes with npm versions) --------------------
FROM base AS tooling

# Install Claude Code
USER node
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# Add Claude to system-wide PATH
ENV PATH="/home/node/.local/bin:${PATH}"

# -- Stage 3: Final image -----------------------------------------------------
FROM tooling AS final

# Copy entrypoint scripts
COPY --chmod=755 scripts/ /usr/local/bin/

# Create workspaces directory with node ownership
RUN mkdir -p /workspaces && chown -R node:node /workspaces

# Pre-create shared-packages mount point with node ownership
# (Docker named volumes default to root, causing EACCES for node user)
RUN mkdir -p /shared-packages && chown node:node /shared-packages

# Credentials architecture: workflow subprocess isolation (v1.5)
# See tetrad-development docs/credentials-architecture-plan.md decision #4.
# These uids exist specifically to enforce uid-boundary isolation between the
# orchestrator/node user, the agent workflow process, and the credhelper daemon
# inside a single worker container. Do NOT consolidate them away — the
# isolation model relies on three distinct uids inside the same container.
#   generacy-workflow (uid 1001): agent processes run as this user during workflows
#   credhelper        (uid 1002): in-worker credhelper daemon runs as this user
RUN useradd --uid 1001 --gid node --no-create-home --shell /bin/bash generacy-workflow \
 && useradd --uid 1002 --gid node --no-create-home --shell /usr/sbin/nologin credhelper

# Credhelper binary + plugins drop here in a future image build.
# Root-owned, world-readable (0755) so the credhelper uid can read/exec, but
# only root can modify the contents at runtime.
RUN mkdir -p /usr/local/lib/generacy-credhelper \
 && chown root:root /usr/local/lib/generacy-credhelper \
 && chmod 0755 /usr/local/lib/generacy-credhelper

# Pre-create the credentials state dir so the named-volume mount inherits
# ownership/mode on first-init. Owned by uid 1000 (node), mode 0700 — see
# .devcontainer/generacy/docker-compose.yml worker service.
RUN mkdir -p /var/lib/generacy \
 && chown node:node /var/lib/generacy \
 && chmod 0700 /var/lib/generacy

# +============================================================================+
# |  Customize below: add your project's system dependencies                    |
# |                                                                             |
# |  Examples:                                                                  |
# |    RUN apt-get update && apt-get install -y python3 python3-pip             |
# |    RUN apt-get update && apt-get install -y postgresql-client               |
# |    RUN npm install -g pnpm@9                                                |
# +============================================================================+

USER node
WORKDIR /workspaces
