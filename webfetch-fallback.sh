#!/usr/bin/env bash
# webfetch-fallback — PostToolUse hook for Claude Code
# Detects failed WebFetch (JS-required sites, Cloudflare blocks, empty SPAs)
# and suggests falling back to a browser MCP (Playwright MCP by default).
#
# Install: see README.md

set -euo pipefail

# Read hook input from stdin (JSON with tool_input + tool_response)
input=$(cat)

# Only process WebFetch tool calls
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[[ "$tool_name" != "WebFetch" ]] && exit 0

# Extract URL and response body
url=$(echo "$input" | jq -r '.tool_input.url // empty')
body=$(echo "$input" | jq -r '.tool_response.content[0].text // .tool_response // empty' 2>/dev/null || echo "")

# If no body, nothing to do
[[ -z "$body" ]] && exit 0

# Failure detection patterns
reason=""

body_len=${#body}
if (( body_len < 500 )); then
  reason="Response body is unusually small (${body_len} bytes) — likely a JS-rendered SPA shell."
elif echo "$body" | grep -qiE 'enable javascript|please enable js|noscript|requires javascript'; then
  reason="Site explicitly requires JavaScript."
elif echo "$body" | grep -qiE 'cloudflare|please verify you are human|just a moment|checking your browser'; then
  reason="Cloudflare/bot-protection challenge detected."
elif echo "$body" | grep -qE '<body[^>]*>\s*(<div[^>]*id="(root|app|__next)"[^>]*>\s*</div>\s*)?</body>'; then
  reason="Body is empty or contains only an SPA mount point (#root, #app, #__next)."
elif echo "$body" | grep -qiE '403 forbidden|429 too many requests|access denied'; then
  reason="HTTP error response (403/429/access denied)."
fi

# No failure detected — exit silently
[[ -z "$reason" ]] && exit 0

# Output structured suggestion as additionalContext
cat <<EOF
{
  "decision": "approve",
  "reason": "WebFetch returned content but it looks broken: ${reason}",
  "additionalContext": "⚠️ WebFetch may have failed on ${url}\n\nReason: ${reason}\n\nSuggested fallback via Playwright MCP:\n\n1. mcp__playwright__browser_navigate({ url: \"${url}\" })\n2. mcp__playwright__browser_snapshot({})\n\nIf Playwright MCP isn't installed, see https://github.com/DevoRia/webfetch-fallback#setup-browser-mcp"
}
EOF
