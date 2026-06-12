---
title: Accuracy & Bug Introduction Analysis
impact: HIGH
tags: accuracy, bugs, reverts, rework, diff-judged
---

# Accuracy & Bug Introduction Analysis

A quality baseline that surfaces where to look deeper. Measures how often code ships without needing follow-up fixes — low rates aren't judgments, they're signals to understand context (risky modules, inherited bugs, deadline pressure).

## The principle: read the change, don't grep the message

**Accuracy is judged by reading diffs, not by matching keywords in commit messages.**

Grepping `fix`/`crash`/`revert` over commit *messages* measures vocabulary, not engineering:

- An engineer who writes terse messages (`update`, `wip`, `changes`) scores a falsely **high** accuracy.
- An engineer who writes honest messages (`fix: null guard in payment capture`) gets **penalized** for good hygiene.
- A commit titled `fix typo in docs` and one titled `fix race condition that double-charged customers` count the same.

That is the exact vanity-metric trap this skill exists to replace. So accuracy is derived during diff reading (Phase 3), where the agent already has every change in front of it. Keyword search is used **only to surface candidates** for the agent to read — never as the verdict itself.

## How the agent judges each commit

While reading a commit diff, classify it into exactly **one** bucket. One verdict per commit — no commit is ever counted twice.

| Verdict | What the diff shows | Counts against accuracy? |
|---------|--------------------|--------------------------|
| **Clean** | New work, or a fix to *inherited* / someone else's code, that holds up | No |
| **Exploratory** | Author reverts/reworks their own recent code as deliberate iteration (spike, A/B, approach swap) | No — this is healthy iteration |
| **Self-rework** | Author repairs a defect they shipped earlier in the window | Yes |
| **Production-breaking** | Defect that broke a shared branch, crashed prod, or was reverted by someone else | Yes — and flag for a closer read |

The distinction between *Exploratory* and *Self-rework* cannot be made from the message — it requires reading what changed and why. That judgment is the whole point.

## Surfacing candidates (mechanical, cheap)

Use git to find commits **worth reading closely** for rework. These are leads, not conclusions.

```bash
# Single mechanical pass: every commit with size, for size-based batching.
./scripts/checkpoint.sh manifest --author "EMAIL" --after YEAR-01-01 --before NEXTYEAR-01-01

# Revert ancestry — which commit reverts which, and whether across authors.
# The agent still READS the reverted diff to grade severity.
git log --after="YEAR-01-01" --before="NEXTYEAR-01-01" --grep="revert" -i \
  --pretty=format:"%H %ae %s" | while read sha email subj; do
    reverted_sha=$(git log -1 --format="%b" "$sha" | grep -oiE '[a-f0-9]{7,40}' | head -1)
    [ -z "$reverted_sha" ] && continue
    orig_author=$(git log -1 --format="%ae" "$reverted_sha" 2>/dev/null)
    if [ "$orig_author" = "$email" ]; then echo "SELF-REVERT  $sha -> $reverted_sha"
    else echo "CROSS-REVERT $sha (by $email) -> $reverted_sha (by $orig_author)"; fi
done
```

Cross-author reverts are the highest-signal leads: someone else had to undo this code. Read both diffs before grading.

To find a commit's own follow-up repairs, let the agent trace the lines: when a diff touches lines that `git blame` attributes to the **same author within the window**, and the change pattern is corrective (a guard added around code they wrote, a value corrected, a branch they added removed), that is self-rework. The agent reads the before/after — it does not trust the word "fix".

## Accuracy calculation (deduped, one verdict per commit)

```
Accuracy = 100% - (commits judged Self-rework or Production-breaking / total commits)
```

Because each commit gets exactly one verdict, the numerator can never exceed the denominator, and overlapping signals (a same-day crash-fix that also strips a debug line) are counted once, not three times.

| Band | Read it as |
|------|-----------|
| >90% | Clean delivery — spot-check the riskiest module to confirm |
| 85-90% | Healthy for complex / heavily-owned surface area |
| 80-85% | Worth a conversation — read the rework cluster for root cause |
| <80% | Read deeply before concluding — often means they own the riskiest code, inherited debt, or shipped under deadline |

These are **investigation bands, not grades**. A band never stands on its own in a report — it must be backed by the specific diffs the agent read. A low band with evidence of owning the payment core is a different story than a low band from careless debug commits, and only reading the diffs tells them apart.

## Severity, from the diff not the label

| Signal the agent sees in the diff | Severity |
|-----------------------------------|----------|
| Reverted by another engineer | Highest — broke things for the team |
| Crash / data-loss / money-path defect | High |
| Repeated repairs to the same logic across several commits | High — the design isn't landing |
| Same-day correction of own code | Medium |
| `--no-verify` visible in the commit (hooks bypassed) | High — flag regardless of size |
| Deliberate iteration / spike reverted cleanly | Low — not a defect |

`--no-verify` is the one thing safe to detect mechanically, because bypassing hooks is a fact, not a judgment:

```bash
git log --author="EMAIL" --after="YEAR-01-01" --before="NEXTYEAR-01-01" \
  --format="%H %s %b" | grep -i "no-verify"
```

## Periodic Saving

After accuracy analysis completes, append results to the contributor's JSONL profile in `.cca/`. Record the **verdict counts the agent assigned from diffs**, so the number is reproducible and traceable to commits:

```json
{"type":"accuracy","timestamp":"2025-01-15T10:30:00Z","period":"2025","total_commits":413,"clean":322,"exploratory":18,"self_rework":58,"production_breaking":15,"accuracy_rate":82.32,"cross_author_reverts":2,"hook_bypass":2,"evidence_file":"alice-2025-rework.md"}
```

`evidence_file` points to the per-commit verdicts the agent wrote while reading — the baseline is never a bare number, it always traces back to the diffs.
