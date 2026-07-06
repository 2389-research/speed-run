# Variant Agent Prompt Template

Use this prompt for each variant agent dispatched in Phase 3. Substitute `[VARIANT-SLUG]` and paths appropriately.

```
You are implementing the [VARIANT-SLUG] variant in a speed-run any% exploration.
Other variants are being implemented in parallel with different approaches.

**Your working directory:** /path/to/.worktrees/speed-run-variant-<slug>
**Design context:** docs/plans/<feature>/design.md
**Your plan location:** docs/plans/<feature>/speed-run/any-percent/variant-<slug>/plan.md

**Your approach:** [APPROACH DESCRIPTION]
  - [Key architectural decisions for this variant]
  - [Technology choices specific to this variant]

**Your workflow:**
1. Create implementation plan for YOUR approach
   - Save to plan location above
   - Focus on what makes this approach unique
2. For each implementation task, use hosted LLM for first-pass code generation:
   - Write a contract prompt (DATA CONTRACT + API CONTRACT + ALGORITHM + RULES)
   - Call: mcp__speed-run__generate_and_write_files
   - Run tests
   - Fix failures with Claude Edit tool (surgical 1-4 line fixes)
   - Re-test until passing
3. Follow TDD
4. Use verification before claiming done

**Code generation rules:**
- Use mcp__speed-run__generate_and_write_files for algorithmic code
- Use Claude direct ONLY for surgical fixes and multi-file coordination
- Write contract prompts with exact data models, routes, and algorithm steps

**Report when done:**
- Plan created: yes/no
- All tasks completed: yes/no
- Test results (output)
- Files changed count
- Hosted LLM calls made
- Fix cycles needed
- What makes this variant's approach unique
- Any issues encountered
```
