#!/usr/bin/env bash
# webfetch-fallback installer — clones repo + adds hook to ~/.claude/settings.json
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude/hooks/webfetch-fallback}"
SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"

echo "📦 Installing webfetch-fallback..."

# Clone or update
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "↻ Updating existing install at $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --quiet
else
  echo "↓ Cloning to $INSTALL_DIR"
  git clone --quiet https://github.com/DevoRia/webfetch-fallback.git "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/webfetch-fallback.sh"

# Add hook to settings.json (idempotent merge with jq)
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# Backup before touching anything
backup="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$backup"
echo "🗂  Backup saved to $backup"

hook_cmd="$INSTALL_DIR/webfetch-fallback.sh"

# Merge strategy:
# - If a PostToolUse entry already matches "WebFetch", append our hook to its
#   `hooks` array (preserving any existing WebFetch hooks the user has).
# - If our exact command is already present, do nothing (idempotent).
# - If no WebFetch entry exists, add a new one.
jq --arg cmd "$hook_cmd" '
  .hooks.PostToolUse |= (
    (. // []) as $entries
    | if any($entries[]; .matcher == "WebFetch") then
        $entries | map(
          if .matcher == "WebFetch" then
            .hooks = (
              (.hooks // []) as $h
              | if any($h[]; .command == $cmd) then $h
                else $h + [{ type: "command", command: $cmd }]
                end
            )
          else . end
        )
      else
        $entries + [{
          matcher: "WebFetch",
          hooks: [{ type: "command", command: $cmd }]
        }]
      end
  )
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

echo "✅ Installed. Hook path: $hook_cmd"
echo "✅ Settings updated: $SETTINGS"
echo ""
echo "Test it: ask Claude to WebFetch a JS-heavy site (e.g. https://app.linear.app)"
echo "You should see a fallback suggestion when it returns empty."
