# Judge Invocation — Any-Percent

Invoke `speed-run:judge` at Phase 4 after all variants complete and fresh-eyes review is done.

```text
Invoke: speed-run:judge

Context to provide:
- Variants to judge: variant-sqlite, variant-postgres, variant-redis
- Worktree locations: .worktrees/speed-run-variant-<slug>/
- Test results from each variant
- Scenario test results
- Fresh-eyes findings
- Speed-run metrics: hosted LLM calls, fix cycles, generation time per variant
```

The judge skill will:
1. Fill out the complete scoring worksheet for each variant
2. Fill out the Speed-Run Metrics table
3. Build the scorecard with integer scores (1-5, no half points)
4. Check hard gates (Fitness Δ≥2, any score=1)
5. Announce winner with rationale (including token efficiency)

**Do not summarize or abbreviate the scoring.** The judge skill output should be the full worksheet.

**Any%-specific context:** In any%, variants explore different architectural approaches, so Fitness differences are expected and valid. A Fitness gap here reflects different design trade-offs, not deviation from a shared design. Weight Craft and Spark higher when approaches are fundamentally different.
