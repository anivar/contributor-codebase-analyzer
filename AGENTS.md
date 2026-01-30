# Contributor Codebase Analyzer — Complete Guide

**Version 3.0.0**
January 2026

> **Note:**
> This document is for AI agents and LLMs to follow when performing code analysis.
> It combines contributor analysis (annual reviews, accuracy, promotion) with codebase
> analysis (repo structure, cross-repo, governance) and periodic saving for resume
> across sessions. Humans may also find it useful, but guidance is optimized for
> automation and consistency by AI-assisted workflows.

---

## Abstract

Unified contributor and codebase analysis system with periodic saving. Two modes:

- **Contributor mode** — reads every commit diff (not sampling), calculates accuracy rates, assesses engineering maturity through qualitative judgment, and generates promotion-ready performance reviews
- **Codebase mode** — maps repository structure, cross-repo relationships, enterprise technology portfolio, technical debt, and security posture

Both modes save checkpoints incrementally to `$PROJECT/.cca/` enabling resume across sessions without re-analyzing prior work.

Based on real-world experience analyzing 1,091 commits across 3 engineers in a React Native restaurant POS codebase.

---

## Table of Contents

1. [Periodic Saving System](#1-periodic-saving-system) — **CRITICAL**
2. [Contributor Analysis](#2-contributor-analysis) — **CRITICAL**
3. [Accuracy & Bug Introduction](#3-accuracy--bug-introduction) — **HIGH**
4. [Code Quality Catalog](#4-code-quality-catalog) — **HIGH**
5. [Qualitative Judgment](#5-qualitative-judgment) — **HIGH**
6. [Report Templates](#6-report-templates) — **HIGH**
7. [Codebase Analysis](#7-codebase-analysis) — **HIGH**
8. [QMD Pairing](#8-qmd-pairing)

---

## 1. Periodic Saving System

**Impact: CRITICAL**

All analysis saves incrementally. Never lose work to session interruptions.

### Directory Layout

```
$PROJECT/.cca/
├── contributors/
│   └── @username/
│       ├── profile.jsonl             # Append-only: one JSON object per analysis run
│       ├── checkpoints/
│       │   ├── 2025-Q1.md           # Quarterly findings snapshot
│       │   └── 2025-Q2.md
│       ├── latest-review.md          # Most recent annual review
│       └── .last_analyzed            # ISO timestamp + last SHA analyzed
├── codebase/
│   ├── structure.json                # Current repo structure
│   ├── dependencies.json             # Dependency catalog
│   └── .last_analyzed
├── governance/
│   ├── portfolio.json                # Technology portfolio
│   ├── debt-registry.json            # Technical debt items
│   ├── security-audit.json           # Last security findings
│   └── .last_analyzed
└── .cca-config.json        # Skill configuration
```

### JSONL Format

First line of every `.jsonl` file is a schema declaration:

```jsonl
{"_schema":"contributor-profile","fields":["type","timestamp","period","data"]}
{"type":"metrics","timestamp":"2025-01-15T10:30:00Z","period":"2025","data":{"commits":413,"prs":89}}
{"type":"accuracy","timestamp":"2025-01-15T11:00:00Z","period":"2025","data":{"accuracy_rate":77.97}}
```

### .last_analyzed Format

```
2025-01-15T12:00:00Z
abc1234def5678
```

Line 1: ISO 8601 timestamp. Line 2: Last git SHA analyzed.

### Resume Protocol

On every invocation:

1. Check `.cca-config.json` exists
2. Read `.last_analyzed` for each contributor/codebase directory
3. Compare last SHA to current HEAD
4. Only analyze commits after the last saved SHA
5. Apply batch sizing rules to new commits only

```bash
if [ -f "$PROJECT/.cca/contributors/@username/.last_analyzed" ]; then
    LAST_SHA=$(tail -1 "$PROJECT/.cca/contributors/@username/.last_analyzed")
    NEW_COMMITS=$(git log --author="EMAIL" "$LAST_SHA"..HEAD --oneline | wc -l)
    if [ "$NEW_COMMITS" -eq 0 ]; then
        echo "Analysis is current — no new commits"
    else
        echo "Resuming from $LAST_SHA — $NEW_COMMITS new commits"
    fi
fi
```

### Save After Each Phase

| Phase | Saved To |
|-------|----------|
| Metrics | `profile.jsonl` (type: metrics) |
| Diff Reading | `checkpoints/YYYY-QN.md` |
| Accuracy | `profile.jsonl` (type: accuracy) |
| Quality | `profile.jsonl` (type: quality) |
| Report | `latest-review.md` |
| Codebase | `codebase/*.json` |
| Governance | `governance/*.json` |

### Configuration

`.cca-config.json`:

```json
{
  "platform": "github",
  "cli_tool": "gh",
  "repo": "org/repo-name",
  "org": "org-name",
  "created_at": "2025-01-15T10:00:00Z",
  "contributors_tracked": ["@alice", "@bob"],
  "default_branch": "main",
  "critical_paths": ["src/modules/payment", "src/modules/orders"],
  "excluded_paths": ["__tests__", "docs/", "*.md"]
}
```

---

## 2. Contributor Analysis

**Impact: CRITICAL**

Mandatory check + 7-phase sequential process for deep-dive contributor analysis.

### Phase 0: Check Before Analyzing

**MANDATORY.** Before any analysis, check if this contributor already has saved work:

```bash
./scripts/checkpoint.sh check contributors/@USERNAME --author EMAIL
```

- **FRESH** → No prior analysis. Run full Phases 1-7.
- **CURRENT** → Already analyzed, no new commits. **Skip entirely.**
- **INCREMENTAL** → New commits since last analysis. Analyze only `LAST_SHA..HEAD`. Append to existing profile.

For `INCREMENTAL`, apply batch sizing to `new_commits` count only. Never re-read already-analyzed commits.

### Batch Sizing Rules

| Commits | Risk | Action |
|---------|------|--------|
| 1-40 | SAFE | Read in main session |
| 41-70 | MODERATE | Single agent → writes to file |
| 71-90 | HIGH | Split into 2 agents |
| 91+ | WILL FAIL | 3+ agents or monthly windows |

**Count commits per quarter BEFORE launching agents:**

```bash
for q in "01-01 04-01" "04-01 07-01" "07-01 10-01" "10-01 NEXTYEAR-01-01"; do
    START=$(echo $q | cut -d' ' -f1)
    END=$(echo $q | cut -d' ' -f2)
    COUNT=$(git log --author="EMAIL" --after="YEAR-$START" --before="YEAR-$END" --oneline | wc -l)
    echo "Q: $COUNT commits"
done
```

### Phase 1: Identity Discovery

```bash
git log --all --format='%ae %an' | sort -u | grep -i "USERNAME"

# Verify platform identity
# GitHub:
gh api users/USERNAME --jq '.login'
# GitLab:
glab api users?username=USERNAME | jq '.[0].username'

# Check noreply formats:
# GitHub: USERID+USERNAME@users.noreply.github.com
# GitLab: USERNAME@users.noreply.gitlab.com
```

Build: `--author=email1 --author=email2`

### Phase 2: Gather Metrics

```bash
# Commits
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --oneline | wc -l

# Monthly breakdown
for month in $(seq -w 1 12); do
    git log --author="EMAIL" --after="YEAR-$month-01" --before="YEAR-$((month+1))-01" --oneline | wc -l
done

# PRs/MRs created (merged) — platform CLI
# GitHub:
gh search prs --author=USERNAME --repo=ORG/REPO --merged --merged=YEAR-01-01..YEAR-12-31 --limit=500 --json number | jq length
# GitLab:
glab mr list --author=USERNAME --state=merged --per-page=100 -o json | jq length

# PRs/MRs reviewed — platform CLI
# GitHub:
gh search prs --reviewed-by=USERNAME --repo=ORG/REPO --merged=YEAR-01-01..YEAR-12-31 --limit=500 --json number | jq length
# GitLab:
glab mr list --reviewer=USERNAME --state=merged --per-page=100 -o json | jq length

# Lines
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --shortstat --oneline | \
  awk '/insertions|deletions/ {ins+=$4; del+=$6} END {print "Added:", ins, "Removed:", del, "Net:", ins-del}'
```

**Save checkpoint:** Append metrics to `profile.jsonl`.

### Phase 3: Read ALL Diffs

Launch quarterly agents per batch sizing rules. Each agent writes findings to file.

**Agent output format:**

```markdown
# Q[N] Findings: USERNAME
**Commits read:** X/Y (coverage %)
**Period:** START — END

## Notable Commits
### [SHORT_SHA] — [COMMIT_MSG]
- **Type:** feature|bugfix|refactor|cleanup|config
- **Modules:** [directories touched]
- **Lines:** +X/-Y (net Z)
- **Complexity:** trivial|moderate|substantial|architectural
- **Quality notes:** [anti-patterns or strengths]
- **Key observation:** [1-2 sentences]

## Anti-Patterns Found
## Strengths Found
## Quarter Summary
```

**Save checkpoint:** Copy findings to `checkpoints/YYYY-QN.md`.

### Phase 4: Bug Introduction

See Section 3.

### Phase 5: Code Quality

See Section 4.

### Phase 6: Report Generation

See Section 6.

**Save checkpoint:** Copy report to `latest-review.md`.

### Phase 7: Comparison

See Section 6 (comparison format).

### Multi-Engineer Orchestration

```
Step 1: Launch ALL data-gathering agents in parallel
Step 2: Engineer 1 → read findings → write report → clear from context
Step 3: Engineer 2 → read findings → write report → clear from context
Step 4: Engineer N → read findings → write report → clear from context
Step 5: Read all reports → write comparison file
```

### Tool Separation

- **Platform CLI** (`gh`/`glab`): Get commit lists, PR/MR counts, review counts, user lookup
- **Local `git`**: Read commit diffs, blame, shortlog from cloned repo (faster, no rate limits)
- Use CLI to discover what to analyze, use local repo to read the actual code

### Context Budget Per Engineer

```
Phase 1-2: Metrics (~5KB)
Phase 3:   Agent launch + confirmations (~1KB per agent)
Phase 3b:  Read findings files (~20KB)
Phase 4:   Bug analysis (~3KB)
Phase 5-7: Report generation (~10KB)
Total:     ~40KB (vs ~250KB without file-based approach)
```

### Production Ownership

Map who owns what in production using `git blame --line-porcelain`.

**SPOF detection:** Flag modules where one person owns >80% (minimum 100 lines).

**Ownership matrix:**

| Category | Ownership | Activity | Meaning |
|----------|-----------|----------|---------|
| Maintained | HIGH | HIGH | Healthy |
| Abandoned | HIGH | LOW | Risk |
| Transitioning | LOW | HIGH | Knowledge transfer |
| Stable | LOW | LOW | Mature, shared |

### API Rate Limits

Platform CLIs are subject to API rate limits. Local `git` has no limits.

| Platform | Limit | Reset |
|----------|-------|-------|
| GitHub (authenticated) | 5,000 requests/hour | Rolling window |
| GitHub (`gh search`) | 30 requests/minute | Per-minute window |
| GitLab (authenticated) | 2,000 requests/minute | Per-minute window |

**Check before heavy operations:**

```bash
# GitHub
gh api rate_limit --jq '.resources.core.remaining'

# Or use the helper
./scripts/checkpoint.sh ratelimit
```

**Contributor analysis is mostly rate-limit-free.** Phases 3-7 use only local `git`. Only Phase 1 (1 call) and Phase 2 (2-4 calls) hit the API. Cross-repo codebase analysis (Tier 2-3) is the highest risk.

**Rate-limit-safe cross-repo pattern:**

```bash
PROCESSED="$PROJECT/.cca/codebase/.repos_processed.txt"
touch "$PROCESSED"

for repo in $(gh repo list ORG --limit 100 --json name --jq '.[].name'); do
    grep -qx "$repo" "$PROCESSED" 2>/dev/null && continue
    REMAINING=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "999")
    if [ "$REMAINING" -lt 10 ]; then
        echo "Rate limited. Saving progress..."
        ./scripts/checkpoint.sh save codebase
        RESET=$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null)
        sleep $((RESET - $(date +%s)))
    fi
    # ... analyze repo ...
    echo "$repo" >> "$PROCESSED"
done
```

For GitLab, add `sleep 0.5` between API calls.

**Pause and resume on rate limit:** Save checkpoint, record processed items in `.repos_processed.txt`, wait for reset, re-run — skips completed work.

### Recovery

If agent fails: halve the batch. If session exhausted: check which files exist, resume from first gap. If rate-limited: save checkpoint, wait for reset, resume.

---

## 3. Accuracy & Bug Introduction

**Impact: HIGH**

A baseline that surfaces where to look deeper — not a score.

### Formula

```
Effective Accuracy = 100% - (fix-related commits / total commits)
```

| Rate | Assessment |
|------|-----------|
| >90% | Excellent |
| 85-90% | Good |
| 80-85% | Needs attention |
| <80% | Needs focused improvement |

### Detection Commands

```bash
# Self-reverts
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --grep="revert" --oneline

# Reverted by others
git log --after="YEAR-01-01" --before="YEAR+1-01-01" --grep="revert" --oneline | while read line; do
    sha=$(echo "$line" | awk '{print $1}')
    reverted_sha=$(git log -1 --format="%b" "$sha" | grep -oP '[a-f0-9]{7,40}')
    if [ -n "$reverted_sha" ]; then
        original_author=$(git log -1 --format="%ae" "$reverted_sha" 2>/dev/null)
        reverter=$(git log -1 --format="%ae" "$sha")
        if [ "$original_author" != "$reverter" ]; then
            echo "REVERTED BY OTHER: $reverter reverted $original_author's $reverted_sha"
        fi
    fi
done

# Same-day self-fixes
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --format="%ad %H %s" --date=short | \
  awk '{date=$1; if(date==prev_date && ($0 ~ /fix/ || $0 ~ /Fix/)) print "SAME-DAY FIX:", $0; prev_date=date}'

# Crash-fix commits
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --grep="crash" -i --oneline | wc -l

# Multi-iteration tickets (4+ commits)
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --format="%s" | \
  grep -oP '[A-Z]+-\d+' | sort | uniq -c | sort -rn | awk '$1 >= 4'

# Hook bypass
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --format="%s %b" | grep -i "no-verify"

# Console cleanup
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" --oneline | grep -iE "console|reactotron" | wc -l
```

### Bug Severity Profile

| Metric | Low | Medium | High |
|--------|-----|--------|------|
| Self-reverts | <=2/year | 3-5 | 6+ |
| Reverted by others | 0 | 1 | 2+ |
| Same-day fixes | <=5/year | 6-15 | 16+ |
| Crash-fix commits | <=5/year | 6-15 | 16+ |
| Hook bypass | 0 | — | Any |

### Nuance

- Exploratory reverts (trying approaches) = lower severity
- Bug-shipping reverts = high severity
- Cross-engineer reverts = highest severity

**Save checkpoint:** Append accuracy to `profile.jsonl`.

---

## 4. Code Quality Catalog

**Impact: HIGH**

### Anti-Patterns

| Pattern | Look For | Severity |
|---------|----------|----------|
| Debug code shipped | console.log, reactotron, test strings | Medium |
| Empty catch blocks | `catch (e) {}` | High (payment) |
| Typos in constants | Misspelled names in production | Medium |
| Value flip-flopping | Same value changed back and forth | Low |
| Mega-commits | 30+ files or 2000+ insertions | Medium |
| Multi-iteration fixes | Same ticket 3+ commits | Medium |
| String-based errors | `error.message.includes()` | Medium |
| Commented-out code | Code commented not deleted | Low |
| Hook bypass | `--no-verify` | High |

### Strengths

| Pattern | Look For | Significance |
|---------|----------|-------------|
| Defensive programming | Null checks, guards, type checks | Production safety |
| Offline-first design | ID management, sync, conflicts | Architecture |
| Optimistic updates | Local state → API → rollback | UX maturity |
| Code reduction | Net negative lines | Engineering maturity |
| Feature gating | Flags, A/B, gradual rollout | Production wisdom |
| Library-level work | Forks, patches, evaluations | Platform engineering |
| Cross-platform | Device/platform conditionals | Breadth |
| Business awareness | Code reflecting business rules | Domain expertise |

### Volume Adjustment

```
Adjusted Volume = Total - fix-related - cleanup - reverts
```

**Save checkpoint:** Append quality to `profile.jsonl`.

---

## 5. Qualitative Judgment

**Impact: HIGH**

Apply AFTER reading all diffs. Provides interpretation layer.

### Engineering Wisdom

**High:** Knows when NOT to refactor, pragmatic over perfect, anticipates needs, production-first, simplification instinct.

**Low:** Trial-and-error commits, debug code shipped, hook bypass under pressure, symptomatic fixing, naming negligence.

### Growth Trajectory

| Pattern | Promotion Signal |
|---------|-----------------|
| Infrastructure → Features → Architecture → Financial | STRONG |
| Consistent features every quarter | MODERATE |
| Accelerating output | MODERATE-STRONG |
| Steady accuracy improvement | STRONG |
| Peak then decline | SUPPORT NEEDED |

### Promotion Readiness

| Signal | Weight |
|--------|--------|
| Architectural capability | HIGH |
| Accuracy >85% | HIGH |
| Production awareness | HIGH |
| Domain breadth (3+) | MEDIUM |
| Code quality (no high-severity) | MEDIUM |
| Consistency (10+/12 months) | MEDIUM |
| Team impact (reviews, patterns) | MEDIUM |

### Growth Areas for Next Level

| Area | Development Goal |
|------|-----------------|
| Accuracy <80% | Improve to 85%+ through review discipline |
| Hook bypass | Adopt pre-commit workflow |
| Crash-fix >15/year | Pair on root-cause analysis |
| No financial tests | Start with highest-risk paths |

### Plateau Detection

Plateaued when 3+ true for 2 consecutive quarters: same work type, same modules, same accuracy, same complexity, no library/platform work, no mentorship.

### Contextual Comparison

Never rank absolutely. Compare by domain:
- "For X domain: Engineer A shows the deepest thinking"
- "For Y domain: Engineer B's breadth is unmatched"

### Key Principles

1. Context > Metrics
2. Trajectory > Position
3. Judgment > Volume
4. Evidence > Opinion
5. Development > Ranking

---

## 6. Report Templates

**Impact: HIGH**

### Growth Assessment Scale

| Level | Label | Meaning |
|-------|-------|---------|
| Outstanding | Clear next-level readiness | Promote with confidence |
| Exceeds Expectations | Strong in key areas | Promote with growth plan |
| Meets Expectations | Solid delivery | Growth areas identified for next level |
| Developing | Focused improvement needed | Structured support and mentorship |
| Needs Support | Significant development required | Dedicated mentorship plan |

### Individual Report Sections

1. Header (name, repo, period, coverage %)
2. Growth Assessment with development recommendation
3. Overall Assessment (2-3 sentences)
4. Executive Summary
5. Contribution Metrics (monthly table, quarterly, aggregate)
6. Technical Impact Assessment (features with commit refs)
7. Accuracy & Bug Profile
8. Code Quality Analysis
9. Performance Review (Recognize 5-7, Discuss 4-6, Develop 5-6, Promotion Assessment)
10. Quarter-by-Quarter Breakdown
11. Footer (coverage, date)

### Comparison File Sections (2+ Engineers)

1. Promotion Recommendation (readiness assessment per engineer)
2. Strengths comparison with contextual justification
3. Overview comparison table
4. Quarterly focus areas
5. Domain ownership map
6. Code quality comparison
7. Accuracy comparison
8. Complexity & brevity
9. Growth trajectory
10. Complementary strengths
11. Post-decision action items

**Save checkpoint:** Copy report to `latest-review.md` in contributor directory.

---

## 7. Codebase Analysis

**Impact: HIGH**

Three tiers for repository and enterprise analysis.

### Tier 1: Repository Structure

```bash
# Module map
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) | \
  sed 's|^\./||;s|/[^/]*$||' | sort -u | head -50

# Dependencies
cat package.json | jq '.dependencies, .devDependencies'

# Entry points
find . -name "index.ts" -o -name "index.tsx" -o -name "main.ts" | head -20
```

Output: `codebase/structure.json`

### Tier 2: Cross-Repo Relationships

```bash
# List org repos
# GitHub:
gh repo list ORG --limit 100 --json name,language,updatedAt
# GitLab (supports nested subgroups):
glab project list --group GROUP --include-subgroups --per-page 100 -o json

# Find shared dependencies
# GitHub:
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | keys[]' 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
# GitLab:
for project_id in $(glab project list --group GROUP --per-page 50 -o json | jq '.[].id'); do
    glab api "projects/$project_id/repository/files/package.json/raw?ref=main" 2>/dev/null | \
      jq -r '.dependencies | keys[]' 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
```

**GitLab note:** GitLab supports nested subgroups (e.g., `org/team/subteam/project`). Use `--include-subgroups` when listing projects to traverse the full hierarchy.

Output: `codebase/dependencies.json`

### Tier 3: Enterprise Governance

```bash
# Tech portfolio — languages across org
# GitHub:
for repo in $(gh repo list ORG --limit 100 --json name --jq '.[].name'); do
    gh api "repos/ORG/$repo/languages" 2>/dev/null | jq -r 'to_entries[] | "\(.key)\t\(.value)"'
done | awk -F'\t' '{lang[$1]+=$2} END {for(l in lang) print lang[l], l}' | sort -rn
# GitLab:
for project_id in $(glab project list --group GROUP --include-subgroups --per-page 100 -o json | jq '.[].id'); do
    glab api "projects/$project_id/languages" 2>/dev/null | jq -r 'to_entries[] | "\(.key)\t\(.value)"'
done | awk -F'\t' '{lang[$1]+=$2} END {for(l in lang) print lang[l], l}' | sort -rn

# Tech debt density
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) -exec \
  grep -l "TODO\|FIXME\|HACK\|XXX" {} \; | wc -l

# Security posture
npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities'
```

Output: `governance/portfolio.json`, `governance/debt-registry.json`, `governance/security-audit.json`

**Save checkpoint:** Write JSON files and update `.last_analyzed`.

---

## 8. QMD Pairing

This skill complements QMD (knowledge search). Division of responsibility:

| Concern | Tool |
|---------|------|
| Search documentation, wikis, specs | QMD |
| Analyze commit diffs, code quality | Code Analyzer |
| Find API references, tutorials | QMD |
| Map repository structure | Code Analyzer |
| Answer "how does X work?" | QMD |
| Answer "who built X and how well?" | Code Analyzer |
| Search across knowledge bases | QMD |
| Track engineering progress over time | Code Analyzer |

When both skills are available, use QMD for understanding WHAT the code should do (from docs) and Code Analyzer for understanding WHAT the code actually does (from commits and diffs).

---

## Prerequisites

- `git` — local repository access (required)
- `gh` — GitHub CLI for PR/review metadata (required for GitHub repos)
- `glab` — GitLab CLI for MR/review metadata (required for GitLab repos)
- `jq` — JSON parsing (optional, for structured output)
- `bc` — arithmetic (for accuracy calculations)

**Auto-detection:** The skill reads `git remote -v` to determine whether the repo is GitHub or GitLab. No manual configuration needed.

## License

MIT
