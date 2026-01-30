---
title: Qualitative Engineering Judgment
impact: HIGH
tags: wisdom, growth, promotion, comparison, feedback, plateau
---

# Qualitative Engineering Judgment

Context-aware, judgment-based analysis of engineering maturity. Apply AFTER reading all commit diffs — provides the interpretation layer on top of quantitative data.

## Engineering Wisdom Assessment

### Indicators of High Wisdom

| Signal | What It Looks Like | Real Example |
|--------|-------------------|-------------|
| Knows when NOT to refactor | Accepts ugly but working code when risk is high | Patching a 698-line file during release freeze |
| Pragmatic over perfect | Ships workable solution, adds TODO for cleanup | Using forked library now, replacing later |
| Anticipates future needs | Just enough abstraction without over-engineering | `getNextAvailableOfflineId()` handling offline edge cases |
| Production-first thinking | Considers deployment, rollback, monitoring | Primary device condition preventing duplicate receipts |
| Simplification instinct | Removes complexity rather than adding layers | Migration achieving -20 net lines with feature parity |

### Growth Opportunities (Areas to Develop)

| Signal | What It Looks Like | Real Example |
|--------|-------------------|-------------|
| Trial-and-error commits | Value flip-flopping across consecutive commits | Default changed 3 times in 2 days |
| Debug code shipped | Test artifacts in production | `"asdad"` string, reactotron left 3.5 months |
| Hook bypass under pressure | Circumventing quality gates | `--no-verify` during crash fix |
| Symptomatic fixing | Addressing symptoms not root cause | Same bug requiring 3 separate commits |
| Naming negligence | Typos in constants that ship | `MANNUAL_PRINT`, `checkBluetoothCOnnectionStatus` |

**Note:** These are development areas, not character flaws. Every engineer exhibits some of these patterns — context matters (pressure, unfamiliarity with module, tight deadlines).

## Situational Decision Analysis

### Emergency Response Quality

```
GOOD: Quick pragmatic fix → works → root-cause fix follows
RISK: Quick fix → breaks something else → another fix → bypasses hooks → still broken
```

Check: First-attempt correctness, hook bypass, root cause vs symptom, crash chains.

### Legacy Code Handling

```
GOOD: Gradual modernization — component by component
GOOD: "Strangler fig" — new system alongside old
RISK: Big bang rewrite breaking existing functionality
RISK: Patching old patterns instead of introducing new ones
```

## Growth Trajectory Assessment

### Quarterly Progression Patterns

| Pattern | Meaning | Promotion Signal |
|---------|---------|-----------------|
| Infrastructure → Features → Architecture → Financial Precision | Clear maturity progression | STRONG |
| Consistent features every quarter | Reliable but may plateau | MODERATE |
| Accelerating output (17→35→34→65) | Sprint builder | MODERATE-STRONG |
| Peak then decline | Possible burnout — check in, don't penalize | SUPPORT NEEDED |
| Steady accuracy improvement | Self-correcting engineer | STRONG |

### Maturity Milestones

- **First architectural decision** — designed a system, not just implemented
- **First library-level contribution** — fork/patch/evaluate a dependency
- **First cross-platform feature** — touched all device/platform layers
- **First production-awareness commit** — monitoring, fallback, degradation
- **First code simplification** — removed more code than added

### Plateau Detection

Contributor has plateaued when 3+ true for 2 consecutive quarters:
- Same type of work (features only, no architecture)
- Same modules touched (no domain expansion)
- Same accuracy rate (not improving)
- Same complexity level
- No library/platform work
- No documentation or mentorship

### Growth Indicators

| Transition | Evidence in Code |
|-----------|-----------------|
| Junior → Mid | Bug fixes → feature implementation; single → multi-file |
| Mid → Senior | Features → architecture; local → system-wide |
| Senior → Staff | Technical → business impact; features → platforms |

### Period-Over-Period Comparison

| Metric | Improving | Static | Declining |
|--------|----------|--------|-----------|
| Accuracy rate | Fix ratio decreasing | Same range | Increasing |
| Complexity | Harder problems | Same difficulty | Simpler work |
| Domain breadth | New modules | Same modules | Narrowing |
| Code reduction | More net-negative commits | Same | Only adding |
| Review engagement | More reviews | Same | Fewer |
| Self-reverts | Decreasing | Same | Increasing |
| Commit granularity | Better-scoped | Same | More mega-commits |

## Promotion Decision Framework

### Readiness Signals

| Signal | Evidence Required | Weight |
|--------|------------------|--------|
| Architectural capability | Built a system from scratch | HIGH |
| Accuracy rate >85% | Fix ratio under 15% | HIGH |
| Domain breadth | Owns 3+ primary domains | MEDIUM |
| Production awareness | Prevents revenue/data loss | HIGH |
| Code quality | No high-severity anti-patterns | MEDIUM |
| Consistency | Active 10+/12 months | MEDIUM |
| Team impact | PR reviews, patterns shared | MEDIUM |
| Library/platform work | Forks, patches, migrations | LOW-MEDIUM |

### Growth Areas for Next Level

These are development goals, not punitive gates. Frame as investments in the engineer's growth:

| Area | Current State → Target | Suggested Timeline |
|------|----------------------|-------------------|
| Accuracy <80% | Improve to 85%+ through review discipline | 3-6 months |
| Hook bypass | Adopt pre-commit workflow | Immediate |
| Crash-fix >15/year | Pair with senior on root-cause analysis | 6 months |
| Typos in constants | Set up spell-check tooling | 1 month |
| No tests for financial logic | Start with highest-risk paths | 3 months |

## Contextual Comparison

Never say "A is better than B." Instead, compare by domain:

```
"For offline-first payment architecture: Alice's system shows the deepest thinking."
"For cross-platform delivery: Bob's SMS deep linking is unmatched."
"For device-level integration: Charlie's breadth is irreplaceable."
```

## Feedback Generation Formats

**Recognize:** `"[Achievement]: [Why it matters]. [Commit reference]."`

**Discuss:** `"[Pattern observed]: [Frequency/severity]. [Impact]. [Question to explore]."`

**Develop:** `"[Growth area]: [Current state]. [Target state]. [Concrete first step]."`

## Key Principles

1. Context > Metrics
2. Trajectory > Position
3. Judgment > Volume
4. Evidence > Opinion
5. Development > Ranking
6. Self-Reverts Have Nuance
7. Volume Needs Adjustment

## Constructive Use Guidelines

This analysis exists to **grow engineers, not judge them.** Follow these principles:

### Do
- Use findings to start development conversations, not deliver verdicts
- Share reports WITH the engineer, not just about them
- Recognize strengths before discussing growth areas
- Consider context: deadlines, on-call, unfamiliar codebase, team changes
- Use `git blame` for knowledge mapping and ownership clarity, not fault-finding
- Frame accuracy rates as improvement trajectories, not scores

### Don't
- Use metrics to justify termination without human context
- Compare engineers as a ranking exercise — compare for complementary strengths
- Treat anti-patterns as character flaws — they're often process or tooling gaps
- Ignore external factors (burnout, team changes, production incidents)
- Share individual accuracy rates publicly or competitively
- Run analysis without the engineer's awareness

### Fairness Checks
- Does the analysis period include major incidents, on-call rotations, or team transitions?
- Are all contributors measured with the same time window and scope?
- Are fix-related commits properly attributed (was the original bug theirs or inherited)?
- Does "low activity" quarter correlate with leave, onboarding, or cross-team work?
- Is the reviewer interpreting patterns charitably before critically?
