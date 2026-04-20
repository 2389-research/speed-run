---
name: speed-run
description: Token-efficient code generation pipeline. Triggers on "speed-run", "fast build", "turbo build", "use hosted LLM", "use cerebras". Routes to turbo (direct codegen), showdown (parallel competition), or any% (parallel exploration). Works out of the box with Haiku; Cerebras is an opt-in speed upgrade.
---

# Speed-Run

Token-efficient code generation pipeline. Offloads first-pass code generation to a cheaper/faster model so Claude Sonnet can focus on architecture and surgical fixes.

Two backends:
- **Haiku** (default, no configuration) — ~5x cheaper than Sonnet, ~150 tokens/sec
- **Cerebras** (opt-in, requires API key) — ~$0.35–0.85/M tokens, ~2000 tokens/sec

Most code is pattern-following, not reasoning. The cheaper/faster model handles the patterns; Claude handles the thinking.

**Announce:** "I'm using speed-run for token-efficient code generation."

## Step 1: Detect Backend

Check `CEREBRAS_API_KEY`:

- **If set**: call `mcp__speed-run__check_status` to confirm Cerebras is reachable.
  - If OK → Cerebras backend available.
  - If the key is set but unreachable (network, wrong key, tier gating) → fall back to Haiku.
- **If not set** → Haiku backend (default).

**Do not block the flow if Cerebras isn't configured.** Haiku is a first-class backend, not a degraded fallback. The plugin works out of the box with no setup.

## Step 2: Announce Backend

Tell the user which backend will be used:

**Haiku:**
```text
Speed-run ready. Using Haiku backend (default).
  • No API key needed — uses your existing Claude access
  • ~5x cheaper than Sonnet for first-pass generation
  • Upgrade tip: set CEREBRAS_API_KEY for ~10x faster generation
```

**Cerebras:**
```text
Speed-run ready. Using Cerebras backend.
  • Model: [model name from check_status]
  • ~2000 tokens/sec generation speed
```

## Step 3: Route

```text
How would you like to proceed?

1. Turbo — Direct code generation (single task, fast)
   → Best for: one feature, algorithmic code, boilerplate
2. Showdown — Parallel competition (same design, multiple runners)
   → Best for: medium-high complexity, want best implementation
3. Any% — Parallel exploration (different approaches)
   → Best for: unsure of architecture, want to compare designs
```

Pass the detected backend to the chosen subskill as `BACKEND=haiku` or `BACKEND=cerebras`.

**Routing:**
- Option 1: Invoke `speed-run:turbo` with `BACKEND=<backend>`
- Option 2: Invoke `speed-run:showdown` with `BACKEND=<backend>`
- Option 3: Invoke `speed-run:any-percent` with `BACKEND=<backend>`

## Skill Dependencies

| Subskill | Description |
|----------|-------------|
| `speed-run:turbo` | Direct codegen via Haiku subagent or Cerebras MCP |
| `speed-run:showdown` | Parallel same-design competition |
| `speed-run:any-percent` | Parallel approach exploration |

## When to Use Speed-Run vs Test Kitchen

| Situation | Use |
|-----------|-----|
| Want token savings on code generation | Speed-run |
| Generating algorithmic code (parsers, state machines) | Speed-run:turbo |
| Want parallel competition with fast generation | Speed-run:showdown |
| Want to explore approaches with fast generation | Speed-run:any% |
| CRUD / simple operations | Test Kitchen (Claude direct is cheaper) |
| Need 100% first-pass accuracy | Test Kitchen |
| Want raw speed (need a Cerebras API key for speed-run) | Speed-run with Cerebras backend |
