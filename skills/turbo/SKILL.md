---
name: turbo
description: Direct code generation via a cheap/fast backend (Haiku by default, or Cerebras if configured). Write a contract prompt, generate code, fix surgically. Part of speed-run pipeline.
---

# Turbo

Direct code generation via a cheaper/faster model. Claude Sonnet writes the contract, the cheap model implements the code, files land on disk. Then tests run, Claude Sonnet surgically fixes anything that didn't pass.

**Announce:** "I'm using speed-run:turbo for offloaded code generation."

## When to Use

**Use turbo for:**
- Algorithmic code (rate limiters, parsers, state machines)
- Multiple files (3+)
- Boilerplate-heavy implementations
- Token-constrained sessions

**Use Claude direct instead for:**
- CRUD/storage operations (Claude Sonnet is cheap enough that fix overhead wipes out savings)
- Single implementation with complex coordination
- Speed-critical tasks where fix cycles are costly

## Backends

Turbo supports two backends. The orchestrator detects and passes one in as `BACKEND`.

| Backend | Configuration | Speed | Cost (vs Sonnet) |
|---------|--------------|-------|------------------|
| **haiku** (default) | Works out of the box | ~150 tok/sec | ~5x cheaper |
| **cerebras** (opt-in) | Needs `CEREBRAS_API_KEY` | ~2000 tok/sec | ~10x cheaper |

The **same contract prompt structure** works for both — the only difference is how generation is dispatched in Step 2 below.

## Tradeoffs

| Aspect | Claude Sonnet direct | Turbo (Haiku) | Turbo (Cerebras) |
|--------|---------------------|---------------|------------------|
| Speed per file | ~10s | ~3–5s | ~0.5s |
| Token cost | Baseline | ~80% savings | ~90% savings |
| First-pass quality | ~100% | 90–95% | 80–95% |
| Fixes needed | 0 | 0–1 typical | 0–2 typical |

## Workflow

### Step 1: Write Contract Prompt

Structure your prompt with exact specifications. This is identical regardless of backend.

```
Build [X] with [tech stack].

## DATA CONTRACT (use exactly these models):

[Pydantic models / interfaces with exact field names and types]

Example:
class Task(BaseModel):
    id: str
    title: str
    completed: bool = False
    created_at: datetime

class TaskCreate(BaseModel):
    title: str

## API CONTRACT (use exactly these routes):

POST /tasks -> Task           # Create task
GET /tasks -> list[Task]      # List all tasks
GET /tasks/{id} -> Task       # Get single task
DELETE /tasks/{id} -> dict    # Delete task
POST /reset -> dict           # Reset state (for testing)

## ALGORITHM:

1. [Step-by-step logic for the implementation]
2. [Include state management details]
3. [Include edge case handling]

## RULES:

- Use FastAPI with uvicorn
- Store data in [storage mechanism]
- Return 404 for missing resources
- POST /reset must clear all state and return {"status": "ok"}
```

### Step 2: Generate Code

**If `BACKEND=cerebras`:**

```
mcp__speed-run__generate_and_write_files
  prompt: [contract prompt]
  output_dir: [target directory]
```

Returns only metadata (files written, line counts). Claude Sonnet never sees the generated code — surgical fixes read it back from disk.

**If `BACKEND=haiku`:**

Dispatch a Haiku subagent with the Agent tool. Give it `Write`, `Edit`, `Read` tool access so it writes files directly.

```
Agent tool:
  subagent_type: "general-purpose"  (or custom if available)
  model: "haiku"
  description: "Speed-run turbo codegen"
  prompt: |
    You are the code generator for a speed-run turbo task.

    Write the files specified below directly to disk using the Write tool.
    Do NOT wrap file contents in <FILE> tags — just call Write for each file.

    Target directory: [target directory]

    [contract prompt from Step 1]

    After writing all files, report a one-line summary:
    "wrote N files: path1, path2, ..."
```

The Haiku subagent returns only the summary. Claude Sonnet reads the written files back from disk when it needs to fix anything.

### Step 3: Run Tests

Run the test suite against generated code.

### Step 4: Fix (if needed)

For failures, use **Claude Edit tool** for surgical fixes (typically 1–4 lines each).

Common fixes:
| Error Type | Frequency | Fix Complexity |
|------------|-----------|----------------|
| Missing utility functions | Occasional | 4 lines |
| Logic edge cases | Occasional | 1–2 lines |
| Import ordering | Rare | 1 line |

**Do not re-dispatch the Haiku subagent or re-call Cerebras** to regenerate files. Claude Sonnet fixing surgically is cheaper and more reliable than regenerating.

### Step 5: Re-test

Repeat Steps 3–4 until all tests pass. Even with fixes, total token cost is much lower than Claude Sonnet generating everything from scratch.

## What the Cheap Backend Gets Right (~90%)

- Data models match contract exactly
- Routes/endpoints correct
- Core algorithm logic
- Basic error handling

## Configuration

No configuration needed for the default Haiku backend.

For Cerebras backend, set these in `~/.claude/settings.json` under `env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CEREBRAS_API_KEY` | (required for Cerebras) | Get free at https://cloud.cerebras.ai |
| `CEREBRAS_MODEL` | `gpt-oss-120b` | Model to use (see tier note) |

The current default `gpt-oss-120b` is gated on some Cerebras tiers. On the free tier, `qwen-3-235b-a22b-instruct-2507` or `llama3.1-8b` work reliably.
