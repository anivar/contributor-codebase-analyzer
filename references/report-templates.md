---
title: Report Templates & Rating Framework
impact: HIGH
tags: report, rating, promotion, comparison, template
---

# Report Templates & Rating Framework

Output formats for individual growth reviews, assessment frameworks, and multi-engineer comparison files.

## Individual Report — Required Sections

1. **Header** — Name, repo, username, email, period, coverage %
2. **Growth Assessment** — Qualitative level with development recommendation
3. **Overall Assessment** — 2-3 sentence summary
4. **Executive Summary** — Full paragraph overview
5. **Contribution Metrics** — Monthly table, quarterly summary, aggregate stats, module distribution
6. **Technical Impact Assessment** — Every major feature with commit refs, scale, depth, safeguards
7. **Accuracy & Bug Introduction Profile** — Table with all accuracy metrics, detailed bug profile
8. **Deep Code Quality Analysis** — Strengths and concerns with specific examples
9. **Performance Review** section:
   - Rating with justification
   - **What to Recognize** — 5-7 points with commit evidence
   - **What to Discuss** — 4-6 areas to explore together in conversation
   - **What to Develop** — 5-6 actionable growth areas for next 12 months
   - **Promotion Readiness Assessment** — RECOMMEND / NOT YET with evidence
10. **Quarter-by-Quarter Breakdown** — Each quarter with count, themes, code-level notes
11. **Footer** — Coverage stats, generation date

## Growth Assessment Scale

Numbers are baselines, not verdicts. Use qualitative levels:

| Level | Meaning | Action |
|-------|---------|--------|
| Outstanding | Clear next-level readiness | Promote with confidence |
| Exceeds Expectations | Strong in key areas | Promote with growth plan |
| Meets Expectations | Solid delivery | Growth areas identified for next level |
| Developing | Focused improvement needed | Structured support and mentorship |
| Needs Support | Significant development required | Dedicated mentorship plan |

## Promotion Assessment Rules

- Base on EVIDENCE from commits, not titles or tenure
- Compare accuracy, complexity-per-commit, domain breadth, architectural impact
- Frame growth areas constructively (e.g., "accuracy trajectory: 78% → target 85%+ with review discipline")
- Provide concrete development plan with timelines for "NOT YET"
- Never say "A is better than B" — use contextual framing

## Comparison File — Required Sections (When 2+ Engineers)

1. **Promotion Recommendation** — Who to promote, who to hold, data-backed rationale
2. **Strengths comparison** with contextual justification
3. **Overview comparison table** — all metrics side by side
4. **Quarterly focus area tables**
5. **Domain ownership map** — primary/secondary/tertiary owners
6. **Code quality comparison** — anti-patterns and strengths side by side
7. **Accuracy comparison** — baseline for where to look deeper
8. **Complexity & brevity analysis**
9. **Growth trajectory visualization** (ASCII)
10. **Complementary strengths** — how they work together
11. **Post-decision action items** — what happens after promotion decisions

## Development Plan Template (for "NOT YET")

```
Month 1-2: Set up tooling (spell-check, lint rules, pre-commit hooks)
Month 3-4: Write unit tests for owned calculation logic
Month 5-6: Track fix-related commit ratio weekly; target <12%
Mid-year check-in: Review metrics; if targets met, recommend promotion
```

## Report File Naming

```
OUTPUT_DIR/
├── USERNAME-YEAR-review.md           # Individual review
├── USERNAME-YEAR-review.md           # Second engineer
├── staff-engineers-YEAR-comparison.md  # Comparison file
```

## Periodic Saving

Reports are saved as the `latest-review.md` in the contributor's checkpoint directory:

```
$PROJECT/.cca/contributors/@USERNAME/latest-review.md
```

Previous reviews are preserved in checkpoints for historical comparison.
