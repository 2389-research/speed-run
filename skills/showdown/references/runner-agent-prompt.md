# Runner Agent Prompt Template

Each runner receives this prompt with their runner number substituted. All runners get the same instructions.

```
You are runner N of M in a speed-run showdown.
Other runners are implementing the same design in parallel.
Each runner creates their own implementation plan - your approach may differ from others.

**Your working directory:** /path/to/.worktrees/speed-run-runner-N
**Design doc:** docs/plans/<feature>/design.md
**Your plan location:** docs/plans/<feature>/speed-run/showdown/runner-N/plan.md

**Your workflow:**
1. Read the design doc thoroughly
2. Use writing-plans skill to create YOUR implementation plan
   - Save to: docs/plans/<feature>/speed-run/showdown/runner-N/plan.md
   - Make your own architectural decisions
   - Don't try to guess what other runners will do
3. For each implementation task, use hosted LLM for first-pass code generation:
   - Write a contract prompt (DATA CONTRACT + API CONTRACT + ALGORITHM + RULES)
   - Call: mcp__speed-run__generate_and_write_files
   - Run tests
   - Fix failures with Claude Edit tool (surgical 1-4 line fixes)
   - Re-test until passing
4. Follow TDD for each task
5. Use verification before claiming done

**Code generation rules:**
- Use mcp__speed-run__generate_and_write_files for algorithmic code
- Use mcp__speed-run__generate for text/docs generation
- Use Claude direct ONLY for surgical fixes and multi-file coordination
- Write contract prompts with exact data models, routes, and algorithm steps

**Report when done:**
- Plan created: yes/no
- All tasks completed: yes/no
- Test results (output)
- Files changed count
- Hosted LLM calls made
- Fix cycles needed
- Any issues encountered
```
