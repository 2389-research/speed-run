# Speed-Run Plugin

## Overview

Speed-run offloads first-pass code generation to a cheap/fast model so Claude Sonnet can focus on architecture decisions and surgical fixes. Same quality code at a fraction of the token cost.

Most code is pattern-following, not reasoning. The cheap backend handles patterns; Claude Sonnet handles the thinking.

## Backends

| Backend | When active | Speed | Cost savings vs Sonnet |
|---------|-------------|-------|------------------------|
| **Haiku** (default) | Always available — no configuration | ~150 tok/sec | ~80% cheaper |
| **Cerebras** (opt-in) | Auto-used when `CEREBRAS_API_KEY` is set and reachable | ~2000 tok/sec | ~90% cheaper |

Speed-run works out of the box with Haiku. Set `CEREBRAS_API_KEY` to upgrade to ~10x faster generation if you need it.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  speed-run (orchestrator skill)                 │
│  Detects backend (Haiku default, Cerebras opt-in)│
│  Routes to subskill with BACKEND= hint          │
├──────────┬──────────┬───────────────────────────┤
│  turbo   │ showdown │  any-percent              │
│  1 task  │ N runners│  N approaches             │
│  direct  │ same spec│  different specs          │
└────┬─────┴────┬─────┴────┬──────────────────────┘
     │          │          │
     v          v          v
┌─────────────────────────────────────────────────┐
│  Dispatch based on BACKEND:                     │
│                                                  │
│  haiku → Agent tool with model="haiku"          │
│          Writes files directly via Write tool   │
│                                                  │
│  cerebras → MCP server (@2389/speed-run-mcp)    │
│             → Cerebras API (qwen-3-235b / etc)  │
└─────────────────────────────────────────────────┘
```

## Prerequisites

### Default (Haiku)

None. Speed-run works out of the box using your existing Claude access.

### Opt-In (Cerebras) — for maximum speed

Get a free key at https://cloud.cerebras.ai and set it in `~/.claude/settings.json`:

```json
{
  "env": {
    "CEREBRAS_API_KEY": "your-key-here"
  }
}
```

Or export in your shell profile:

```bash
export CEREBRAS_API_KEY="your-key-here"
```

Restart Claude Code after setting the key. On startup, speed-run will detect it and switch to the Cerebras backend automatically.

### MCP Server (Cerebras only)

The MCP server auto-registers via `.mcp.json` and is only used when Cerebras is active. If `mcp__speed-run__*` tools aren't available after setting `CEREBRAS_API_KEY`, build manually:

```bash
cd ./mcp && npm install && npm run build
```

## Skills

### Routing

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `speed-run` | "speed-run", "turbo", "fast codegen", "cerebras" | Orchestrator. Checks API key, presents options. |
| `speed-run:turbo` | Single task, straightforward codegen | Direct generation. One contract prompt, one output. |
| `speed-run:showdown` | Multiple implementations of the same spec | Parallel competition. N runners implement the same design, judge picks the winner. |
| `speed-run:any-percent` | Multiple architectural approaches | Parallel exploration. N variants try different approaches, judge evaluates tradeoffs. |
| `speed-run:judge` | Called by showdown/any-percent | Scoring framework. 5 criteria, 25 points max, hard gates on critical flaws. |

### Turbo (Direct Codegen)

The simplest path. Use when you have one task and want fast generation.

**Flow:**
1. Write a contract prompt (DATA CONTRACT, API CONTRACT, ALGORITHM, RULES)
2. Call `mcp__speed-run__generate_and_write_files` with the prompt
3. Run tests
4. If tests fail, Claude fixes surgically (don't regenerate the whole thing)
5. Re-test until green

**Best for:** Algorithmic code, boilerplate, data transformations, multi-file scaffolding.

**Not great for:** Novel architecture decisions, complex business logic, anything requiring deep reasoning about tradeoffs.

### Showdown (Parallel Competition)

Same design doc, multiple runners implement it independently. The judge scores all variants and picks a winner.

**Flow:**
1. Assess complexity → decide runner count (2-5)
2. Write a shared design document
3. Dispatch all runners in a single message (parallel agents)
4. Each runner: hosted LLM generates → tests → Claude fixes
5. Judge scores all variants (fitness, complexity, readability, robustness, maintainability)
6. Winner gets promoted, losers get cleaned up

**Critical:** Dispatch all runners in a single message. Sequential dispatch defeats the purpose.

### Any-Percent (Parallel Exploration)

Different architectural approaches to the same problem. Unlike showdown, each variant uses a different strategy.

**Flow:**
1. Gather context about the problem
2. Identify 2-5 distinct approaches (e.g., "event-driven vs polling vs hybrid")
3. Write a plan document defining each approach
4. Dispatch all variants in a single message
5. Each variant: hosted LLM generates → tests → Claude fixes
6. Judge evaluates tradeoffs across approaches
7. Winner gets promoted

**Best for:** When you genuinely don't know which approach is right and want to let the code speak.

### Judge (Scoring Framework)

Evaluates implementations across 5 criteria, each scored 1-5:

| Criterion | What it measures |
|-----------|-----------------|
| Fitness for Purpose | Does it actually do what was asked? (8 checkboxes) |
| Justified Complexity | Is the complexity earned? (line count analysis) |
| Readability | Can someone else understand it? (violation counting) |
| Robustness & Scale | Will it hold up? (12-item checklist) |
| Maintainability | Can it evolve? (6-item checklist) |

**Hard gates:** Fitness delta >= 2 between variants, or any score of 1, triggers automatic disqualification.

## Backend dispatch

### Haiku backend (default)

No MCP involved. Skills dispatch an Agent tool subagent with `model="haiku"`, `Write`/`Edit`/`Read` tool access, and the contract prompt. The Haiku subagent writes files directly to disk — no `<FILE>` tag parsing needed. Sonnet reads the files back from disk when surgical fixes are required.

### Cerebras backend (opt-in)

Used when `CEREBRAS_API_KEY` is set. Skills call the MCP server tools:

| Tool | Purpose |
|------|---------|
| `mcp__speed-run__generate` | Send a prompt to Cerebras, get raw text back |
| `mcp__speed-run__generate_and_write_files` | Send a prompt, parse file blocks from response, write to disk |
| `mcp__speed-run__check_status` | Verify API key is set and Cerebras is reachable |

### File output format (Cerebras only)

The Cerebras MCP server parses generated code from XML-style tags:

```text
<FILE path="src/main.py">
def hello():
    print("hello world")
</FILE>
```

Two legacy fallback formats (`### FILE: path` with fenced blocks, or raw content) are supported but not recommended.

If generated code contains literal triple backticks, use `TRIPLE_BACKTICK` as a placeholder - the server auto-replaces after extraction.

The Haiku backend doesn't need this — the subagent just calls Write directly.

## Speed-run vs test kitchen

| Aspect | Test Kitchen | Speed-Run (Haiku) | Speed-Run (Cerebras) |
|--------|-------------|-------------------|----------------------|
| Code generation | Claude Sonnet | Claude Haiku subagent | Cerebras hosted LLM |
| API key required | No | No | Yes (CEREBRAS_API_KEY) |
| Token cost | Baseline | ~80% savings | ~90% savings |
| Generation speed | ~10s per file | ~3-5s per file | ~0.5s per file |
| First-pass quality | ~100% | 90-95% | 80-95% |
| Fix strategy | Rarely needed | Surgical fixes by Sonnet | Surgical fixes by Sonnet |
| Best for | Any task | Algorithmic code, boilerplate, multi-variant |

Use test-kitchen when first-pass quality matters most. Use speed-run when you want speed and token savings and don't mind a fix cycle.

## Skill dependencies

| Dependency | Used By | Purpose |
|------------|---------|---------|
| `speed-run:judge` | showdown, any-percent | Scoring framework (bundled) |
| `superpowers:dispatching-parallel-agents` | showdown, any-percent | Parallel dispatch |
| `superpowers:using-git-worktrees` | showdown, any-percent | Isolated workspaces |
| `superpowers:verification-before-completion` | all | Verify before claiming done |
| `fresh-eyes-review:skills` | showdown, any-percent | Quality gate before comparison |

## Common mistakes

Don't re-dispatch the cheap backend when tests fail. Claude Sonnet should read the error and fix it surgically. The cheap backend already did the structural work — regenerating from scratch wastes the effort.

Showdown and any-percent must dispatch all runners in a single message. Running them one at a time defeats the whole point of parallelism.

Turbo needs structured contract prompts (DATA CONTRACT, API CONTRACT, etc). If you send it a vague prompt, you get vague code back.

Don't use speed-run for tasks that require actual reasoning about architecture or tradeoffs. The cheap backend is fast at following patterns, not at thinking. Use Claude Sonnet directly for those.

If the Cerebras backend isn't working, check `mcp__speed-run__check_status`. The plugin automatically falls back to Haiku when Cerebras is unreachable.

## Configuration

No configuration is required for the default Haiku backend.

For the Cerebras backend:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CEREBRAS_API_KEY` | (required for Cerebras) | API key from https://cloud.cerebras.ai |
| `CEREBRAS_MODEL` | `gpt-oss-120b` | Model to use (see tier note) |
| `CEREBRAS_URL` | `https://api.cerebras.ai/v1` | API endpoint |
| `GENERATION_TIMEOUT` | `120` | Fetch timeout in seconds (not ms) |

### Model selection (Cerebras)

Some Cerebras models are gated by tier. On the free tier, these work: `qwen-3-235b-a22b-instruct-2507`, `llama3.1-8b`. These are gated (404 on `/chat/completions`) on free tier: `gpt-oss-120b` (current default), `zai-glm-4.7`. Set `CEREBRAS_MODEL` explicitly if you hit gating.
