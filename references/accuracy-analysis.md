---
title: Accuracy & Bug Introduction Analysis
impact: HIGH
tags: accuracy, bugs, reverts, crash-fix, hook-bypass
---

# Accuracy & Bug Introduction Analysis

A quality baseline that surfaces where to look deeper. Measures how often code ships without needing follow-up fixes — low rates aren't judgments, they're signals to understand context (risky modules, inherited bugs, deadline pressure).

## Quick Reference

```
Effective Accuracy = 100% - (fix-related commits / total commits)
```

| Rate | Assessment |
|------|-----------|
| >90% | Excellent — clean delivery |
| 85-90% | Good — acceptable for complex work |
| 80-85% | Needs attention — review process or tooling may help |
| <80% | Needs focused improvement — identify root causes together |

## Detection Commands

```bash
# Self-reverts
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --grep="revert" --oneline

# Reverted BY OTHERS (critical — code broke things for the team)
git log --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --grep="revert" --oneline | while read line; do
    sha=$(echo "$line" | awk '{print $1}')
    reverted_sha=$(git log -1 --format="%b" "$sha" | grep -oP '[a-f0-9]{7,40}')
    if [ -n "$reverted_sha" ]; then
        original_author=$(git log -1 --format="%ae" "$reverted_sha" 2>/dev/null)
        reverter=$(git log -1 --format="%ae" "$sha")
        if [ "$original_author" != "$reverter" ]; then
            echo "REVERTED BY OTHER: $sha reverted $reverted_sha"
            echo "  by $reverter, original by $original_author"
        fi
    fi
done

# Same-day self-fix patterns
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --format="%ad %H %s" --date=short | \
  awk '{
    date=$1
    if(date==prev_date && ($0 ~ /fix/ || $0 ~ /Fix/ || $0 ~ /FIX/))
      print "SAME-DAY FIX:", $0
    prev_date=date
  }'

# Crash-fix commits
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --grep="crash" -i --oneline | wc -l

# Tickets needing 4+ commits (multi-iteration fixes)
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --format="%s" | \
  grep -oP '[A-Z]+-\d+' | sort | uniq -c | sort -rn | awk '$1 >= 4'

# Hook bypass detection
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --format="%s %b" | grep -i "no-verify"

# Console.log/reactotron cleanup commits
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --oneline | grep -iE "console|reactotron|removing console|remove console" | wc -l
```

## Accuracy Calculation

```
Fix-Related = self-reverts + same-day-fixes + crash-fixes + console-cleanup
Fix Ratio   = Fix-Related / Total Commits
Effective Accuracy = 100% - Fix Ratio
```

## Nuance: Not All Reverts Are Equal

- **Exploratory reverts** (trying approaches, then reverting) = lower severity
- **Bug-shipping reverts** (code broke production) = high severity
- **Cross-engineer reverts** (someone else had to revert your code) = highest severity

Check the commit message and context to distinguish.

## Bug Severity Profile

| Metric | Low Severity | Medium | High |
|--------|-------------|--------|------|
| Self-reverts | <=2/year | 3-5 | 6+ |
| Reverted by others | 0 | 1 | 2+ |
| Same-day fixes | <=5/year | 6-15 | 16+ |
| Crash-fix commits | <=5/year | 6-15 | 16+ |
| Hook bypass | 0 | — | Any |
| 4+ commit tickets | <=3/year | 4-8 | 9+ |

## Periodic Saving

After accuracy analysis completes, append results to the contributor's JSONL profile in `.cca/`:

```json
{"type":"accuracy","timestamp":"2025-01-15T10:30:00Z","period":"2025","total_commits":413,"fix_related":91,"accuracy_rate":77.97,"self_reverts":3,"reverted_by_others":0,"same_day_fixes":42,"crash_fixes":15,"hook_bypass":2,"console_cleanup":29}
```

This enables tracking accuracy improvement over time without re-analyzing old commits.
