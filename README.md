# webfetch-fallback

> A 50-line Claude Code hook that detects failed `WebFetch` calls (JS-required SPAs, Cloudflare blocks, empty React shells) and tells Claude to retry via the browser MCP instead.

[![bash](https://img.shields.io/badge/bash-50%20lines-blue.svg)]()
[![license](https://img.shields.io/badge/license-MIT-green.svg)]()

## The problem

Claude Code's `WebFetch` tool can't run JavaScript. When you ask Claude to fetch a React/Next/Vue site, half the time you get back something like:

```html
<!DOCTYPE html>
<html><head>...</head><body><div id="root"></div></body></html>
```

— an empty SPA shell. Claude has no idea the fetch failed. It either hallucinates content or wastes a turn telling you "the page seems empty."

Same story for Cloudflare-protected sites, login walls, and 403/429 responses.

## The fix

A `PostToolUse` hook that runs after every `WebFetch`, checks the response for failure patterns, and (if found) injects a suggestion to fall back to a browser MCP (Claude in Chrome, Playwright MCP, Browserbase, etc.).

Claude reads the suggestion, retries via browser, gets real content. You don't lose a turn.

## Detected failure patterns

| Pattern | Example |
|---|---|
| Body < 500 bytes | SPA shell |
| `enable javascript` / `noscript` | "Please enable JavaScript to continue" |
| Cloudflare challenge | "Just a moment...", "Please verify you are human" |
| Empty mount points | `<div id="root"></div>` |
| HTTP 403 / 429 / "access denied" | Bot blocks |

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/DevoRia/webfetch-fallback/main/install.sh | bash
```

This clones the repo to `~/.claude/hooks/webfetch-fallback` and adds the hook to your `~/.claude/settings.json`.

## Manual install

1. Clone:
   ```bash
   git clone https://github.com/DevoRia/webfetch-fallback.git ~/.claude/hooks/webfetch-fallback
   chmod +x ~/.claude/hooks/webfetch-fallback/webfetch-fallback.sh
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "WebFetch",
           "hooks": [
             { "type": "command", "command": "/Users/YOU/.claude/hooks/webfetch-fallback/webfetch-fallback.sh" }
           ]
         }
       ]
     }
   }
   ```

3. Restart Claude Code.

## Setup (browser MCP)

The hook only *suggests* fallback — Claude executes it via your existing browser MCP. Common options:

- **Claude in Chrome** — Anthropic's Chrome extension
- **Playwright MCP** — Microsoft's headless-browser MCP
- **Browserbase MCP** — hosted browser automation

If none installed, the hook still fires but Claude won't have a tool to fall back to. The hook references Playwright MCP tool names by default; if you use a different MCP, edit the suggestion at the bottom of `webfetch-fallback.sh`.

## How it works

```
┌─────────────┐         ┌──────────────────┐         ┌──────────────┐
│ Claude calls│   →    │ WebFetch returns  │    →   │ PostToolUse   │
│  WebFetch   │         │ empty SPA shell   │         │ hook fires   │
└─────────────┘         └──────────────────┘         └──────┬───────┘
                                                            │
                                              ┌─────────────▼──────────────┐
                                              │ Hook detects failure       │
                                              │ → injects additionalContext│
                                              │ → suggests browser MCP     │
                                              └─────────────┬──────────────┘
                                                            │
                                                 ┌──────────▼──────────┐
                                                 │ Claude reads context│
                                                 │ → calls browser MCP │
                                                 │ → gets real content │
                                                 └─────────────────────┘
```

## FAQ

**Q: Does this slow down WebFetch?**
A: No. Hook runs *after* WebFetch returns. Adds ~5ms (single bash + jq pass).

**Q: What if I don't have a browser MCP installed?**
A: Hook still fires, but Claude has no fallback tool. Suggestion is harmless — Claude will just say "WebFetch returned empty, can you fetch manually?"

**Q: Does it work with custom WebFetch wrappers?**
A: The hook matches on `tool_name == "WebFetch"`. If you use a different name, edit the matcher line in `webfetch-fallback.sh`.

**Q: False positives?**
A: Rarely. <500 byte threshold can hit very small valid pages (status APIs). Tune the threshold in the script if it bothers you.

**Q: Why bash, not Node?**
A: Zero install. `bash` + `jq` are everywhere. Hook is 50 lines.

## Contributing

Issues and PRs welcome. Especially:
- New failure patterns you've hit
- Tests against real-world SPA URLs
- Auto-fallback (V2: invoke browser MCP directly from hook, no Claude round-trip)

## License

MIT — do whatever, no warranty.

## Author

Built by [DevoRia](https://github.com/DevoRia) — solo dev shipping Claude Code tooling.

If this saves you a turn, ⭐ the repo. That's the only metric I track.
