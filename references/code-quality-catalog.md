---
title: Code Quality Catalog
impact: HIGH
tags: anti-patterns, strengths, quality, code-review
---

# Code Quality Catalog

Systematic catalog of anti-patterns to flag and strengths to recognize when reading commit diffs. Apply during Phase 5 of annual review analysis.

## Anti-Patterns to Flag

| Pattern | What to Look For | Severity |
|---------|-----------------|----------|
| Debug code shipped | `console.log`, reactotron, `"asdad"`, hardcoded test values | Medium |
| Empty catch blocks | `catch (e) {}` or `catch (e) { /* */ }` | High (payment code) |
| Typos in constants | Misspelled function/constant names shipped to production | Medium |
| Value flip-flopping | Same value changed back and forth across commits | Low |
| Mega-commits | 30+ files or 2000+ insertions in single commit | Medium |
| Multi-iteration fixes | Same ticket requiring 3+ commits to resolve | Medium |
| String-based error matching | `error.message.includes("...")` instead of error codes | Medium |
| Commented-out code | Code commented rather than deleted | Low |
| Hook bypass | `--no-verify` usage | High |

## Strengths to Recognize

| Pattern | What to Look For | Significance |
|---------|-----------------|-------------|
| Defensive programming | Null checks, validation guards, type checks | Production safety |
| Offline-first design | ID management, sync handling, conflict resolution | Architecture depth |
| Optimistic updates | Local state → API call → rollback on failure | UX maturity |
| Code reduction | Net negative lines while maintaining functionality | Engineering maturity |
| Feature gating | Feature flags, A/B test integration, gradual rollout | Production wisdom |
| Library-level work | Forks, patches, evaluating alternatives | Platform engineering |
| Cross-platform handling | Device/platform conditionals done correctly | Breadth |
| Business-domain awareness | Code reflecting real-world business rules | Domain expertise |

## Volume Adjustment

Raw commit count is misleading. Adjust:

```
Adjusted Volume = Total commits - fix-related - cleanup - reverts
```

Example: 413 raw commits, 21.9% fix-related = ~322 effective commits.

## Complexity-Per-Commit Assessment

Weight by type:
- New system from scratch → HIGH complexity regardless of lines
- Edge case bug fix (1 line) → LOW complexity, possibly high judgment
- Mega-commit (34 files, 2388 insertions) → HIGH volume, questionable granularity
- Library evaluation and migration → HIGH judgment, medium volume

## Cataloging During Diff Reading

When reading each commit diff, record quality observations:

```markdown
### [SHA] — [commit message]
- **Anti-patterns:** [list any from catalog above, or "none"]
- **Strengths:** [list any from catalog above, or "none"]
- **Severity note:** [context — e.g., "empty catch in payment flow = HIGH"]
```

Aggregate at the end of each quarter for the quality summary.

## Periodic Saving

Quality findings are saved per-quarter in the findings files. The aggregate is also appended to the contributor JSONL profile in `.cca/`:

```json
{"type":"quality","timestamp":"2025-01-15T10:30:00Z","period":"2025-Q1","anti_patterns":{"debug_code":3,"empty_catch":1,"hook_bypass":0},"strengths":{"defensive_programming":12,"code_reduction":5,"offline_first":3}}
```
