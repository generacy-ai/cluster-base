#!/bin/bash
# Seed this container's ~/.claude.json from the read-only cluster seed.
#
# Clusters used to bind the operator's live ~/.claude.json read-write into the
# orchestrator and every worker. That file is per-HOST, not per-cluster, so all
# clusters on a machine shared one config — and `generacy setup build` writes an
# absolute, image-flavour-specific agency CLI path into `mcpServers.agency`.
# Whichever cluster bootstrapped last silently overwrote that entry for every
# other cluster, leaving e.g. a source-build cluster pointing at a
# /shared-packages path its containers do not have. The only visible symptom was
# an Agency MCP server that failed to start, so speckit commands quietly fell
# back to raw bash.
#
# The scaffolder now mounts a filtered seed read-only at /seed/claude.json and
# each container copies it here, so nothing writes through to a shared file.
#
# Copy only when missing: `generacy setup build` rewrites mcpServers on every
# start anyway, and re-seeding would discard any per-container state the CLI
# accumulated (and any manual `claude mcp add`).
#
# No-ops when no seed is mounted, so this is safe on a compose file that still
# binds ~/.claude.json directly — ordering between the image and the scaffolder
# release does not matter.

SEED_PATH="${CLAUDE_CONFIG_SEED:-/seed/claude.json}"
TARGET_PATH="${HOME}/.claude.json"

seed_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [seed-claude-config] $*"
}

if [ -f "$TARGET_PATH" ]; then
    seed_log "${TARGET_PATH} already present — leaving it alone"
    exit 0
fi

if [ ! -f "$SEED_PATH" ]; then
    # Nothing to seed from. Claude Code creates its own config on first run;
    # this is not an error, just an unseeded container.
    seed_log "No seed at ${SEED_PATH} — starting with an empty Claude config"
    exit 0
fi

if cp "$SEED_PATH" "$TARGET_PATH" 2>/dev/null; then
    chmod 0600 "$TARGET_PATH" 2>/dev/null || true
    seed_log "Seeded ${TARGET_PATH} from ${SEED_PATH}"
else
    seed_log "WARNING: could not copy ${SEED_PATH} to ${TARGET_PATH}; continuing"
fi

exit 0
