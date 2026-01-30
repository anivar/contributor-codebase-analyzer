---
title: Deep-Dive Contributor Analysis
impact: CRITICAL
tags: contributor, annual-review, diffs, identity, metrics, batch-sizing
---

# Deep-Dive Contributor Analysis

Complete process for analyzing a contributor's performance by reading every commit diff. Merges the annual review pipeline with agent context management for reliable execution at scale.

Based on real-world experience analyzing 1,091 commits across 3 engineers in a React Native restaurant POS codebase.

## Arguments Format

```
Analyze contributor "USERNAME" for YEAR annual review in repo ORG/REPO.
Write output to OUTPUT_PATH.
```

Extract: USERNAME (GitHub/GitLab username), YEAR, ORG/REPO, OUTPUT_PATH.
Email is NOT required — the skill auto-discovers it from git history.

## Phase 0: Check Before Analyzing

**MANDATORY first step.** Before any analysis, check if this contributor has already been analyzed:

```bash
./scripts/checkpoint.sh check contributors/@USERNAME --author EMAIL
```

| Output | Meaning | Action |
|--------|---------|--------|
| `FRESH` | No prior analysis | Run full analysis (Phases 1-7) |
| `CURRENT` | Already analyzed, no new commits | Skip — analysis is complete |
| `INCREMENTAL` | Prior analysis exists, new commits found | Analyze only commits after `last_sha` |

For `INCREMENTAL`, the output includes `last_sha` and `new_commits` count. Use `last_sha` as the starting point:

```bash
# Only analyze commits after the last checkpoint
git log --author="EMAIL" LAST_SHA..HEAD --oneline
```

Apply batch sizing rules to `new_commits` only. Append new findings to existing profile — never overwrite.

## Phase 1: Identity Discovery

Contributors often have multiple git identities. Discover ALL from git history before counting.

```bash
# Find all email variants from git log (the primary discovery method)
git log --all --format='%ae %an' | sort -u | grep -i "USERNAME_OR_NAME"

# Verify platform identity
# GitHub:
gh api users/USERNAME --jq '.login'
# GitLab:
glab api users?username=USERNAME | jq '.[0].username'

# Check noreply formats:
# GitHub: USERID+USERNAME@users.noreply.github.com
# GitLab: USERNAME@users.noreply.gitlab.com
```

Build author filter: `--author=email1 --author=email2 --author=noreply`

## Phase 2: Gather Metrics

```bash
# Total commits (ALL email variants)
git log --author="EMAIL1" --author="EMAIL2" \
  --after="YEAR-01-01" --before="YEAR+1-01-01" --oneline | wc -l

# Monthly breakdown
for month in $(seq -w 1 12); do
    NEXT_MONTH=$((10#$month + 1))
    NEXT_YEAR=$YEAR
    if [ "$NEXT_MONTH" -gt 12 ]; then NEXT_MONTH=1; NEXT_YEAR=$((YEAR+1)); fi
    NEXT_MONTH=$(printf "%02d" $NEXT_MONTH)
    COUNT=$(git log --author="EMAIL" \
      --after="$YEAR-$month-01" --before="$NEXT_YEAR-$NEXT_MONTH-01" --oneline | wc -l)
    echo "Month $month: $COUNT commits"
done

# PRs/MRs created (merged) — platform CLI
# GitHub:
gh search prs --author=USERNAME --repo=ORG/REPO --merged \
  --merged=YEAR-01-01..YEAR-12-31 --limit=500 --json number | jq length
# GitLab:
glab mr list --author=USERNAME --state=merged --per-page=100 -o json | jq length

# PRs/MRs reviewed — platform CLI
# GitHub:
gh search prs --reviewed-by=USERNAME --repo=ORG/REPO \
  --merged=YEAR-01-01..YEAR-12-31 --limit=500 --json number | jq length
# GitLab:
glab mr list --reviewer=USERNAME --state=merged --per-page=100 -o json | jq length

# Lines added/removed — local git
git log --author="EMAIL" --after="YEAR-01-01" --before="YEAR+1-01-01" \
  --shortstat --oneline | \
  awk '/insertions|deletions/ {ins+=$4; del+=$6} END {
    print "Added:", ins, "Removed:", del, "Net:", ins-del
  }'
```

## Phase 3: Read ALL Commit Diffs

**DO NOT sample. READ ALL.** This is the core differentiator of this skill.

### Step 1: Count commits per quarter BEFORE launching agents

```bash
for q in "01-01 04-01" "04-01 07-01" "07-01 10-01" "10-01 NEXTYEAR-01-01"; do
    START=$(echo $q | cut -d' ' -f1)
    END=$(echo $q | cut -d' ' -f2)
    COUNT=$(git log --author="EMAIL" \
      --after="YEAR-$START" --before="YEAR-$END" --oneline | wc -l)
    echo "Q: $COUNT commits"
done
```

### Step 2: Choose batch strategy

| Commits in batch | Risk Level | Action |
|-----------------|------------|--------|
| 1-40 | SAFE | Read in main session, no agent needed |
| 41-70 | MODERATE | Single agent, writes findings to file |
| 71-90 | HIGH | Split into 2 sub-agents |
| 91+ | WILL FAIL | Split into 3+ sub-agents or monthly windows |

**Real failure:** A Q1 batch of 106 commits exceeded agent prompt limits — caused a 20.7% coverage gap. Should have been split into monthly agents.

### Step 3: Agent output protocol

Each agent MUST write structured findings to a file, not return inline.

```
SCRATCHPAD/
├── USERNAME-Q1-findings.md
├── USERNAME-Q2-findings.md
├── USERNAME-Q3-findings.md
└── USERNAME-Q4-findings.md
```

**Findings file format:**

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
- [pattern]: [SHA] — [description]

## Strengths Found
- [pattern]: [SHA] — [description]

## Quarter Summary
- Themes: [2-3 sentences]
- Complexity trend: [increasing/stable/decreasing]
- Key achievement: [most important contribution]
```

### Step 4: Launch agents in parallel

For a typical 3-engineer analysis (12-24 agents total), launch in batches:
- Batch 1: All Q1 agents for all engineers (parallel)
- Batch 2: All Q2 agents (parallel)
- etc.

### Context budget per engineer

```
Phase 1-2: Metrics gathering (~5KB)
Phase 3:   Agent launch + confirmations (~1KB per agent)
Phase 3b:  Read findings files (~5KB per quarter = ~20KB)
Phase 4:   Bug analysis (~3KB)
Phase 5-7: Report generation (~10KB)
Total:     ~40KB (vs ~250KB without file-based approach)
```

## Phase 4: Bug Introduction Analysis

See `accuracy-analysis.md` for full commands and formula.

## Phase 5: Code Quality Deep Analysis

See `code-quality-catalog.md` for anti-pattern and strength catalogs.

## Phase 6: Generate Performance Review Report

See `report-templates.md` for required sections, growth assessment framework, and development recommendations.

## Phase 7: Comparison File (Multiple Engineers)

See `report-templates.md` for comparison format (11 required sections).

## Multi-Engineer Orchestration

```
Step 1: Launch ALL data-gathering agents in parallel (all engineers, all quarters)
Step 2: Process Engineer 1 → read findings → write report → clear from context
Step 3: Process Engineer 2 → read findings → write report → clear from context
Step 4: Process Engineer N → read findings → write report → clear from context
Step 5: Read all N report files → write comparison file
```

## Production Ownership Mapping

Different from commit activity — an engineer might have high commit volume but low ownership (code refactored away), or low recent commits but high ownership (built stable core systems).

### Identify production files

```bash
# Detect production branch
for branch in main master production prod release; do
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        PROD_BRANCH=$branch; break
    fi
done

# Get production source files (exclude non-deployed code)
git ls-files | \
    grep -v -E "__tests__|\.test\.|\.spec\.|test/|tests/|spec/" | \
    grep -v -E "\.md$|docs/|README|CHANGELOG|LICENSE" | \
    grep -v -E "examples/|samples/|mock|fixture|storybook" | \
    grep -v -E "\.lock$|package-lock|yarn\.lock" | \
    grep -E "\.(js|ts|jsx|tsx|py|java|go|rb|swift|kt|rs|c|cpp|h)$" \
    > /tmp/production_files.txt
```

### Module-level ownership

```bash
# Extract module directories (2 levels deep)
cat /tmp/production_files.txt | \
    awk -F/ '{if(NF>=3) print $1"/"$2; else print $1}' | \
    sort -u > /tmp/modules.txt

# For each module, find primary owner via git blame
while IFS= read -r module; do
    MODULE_FILES=$(grep "^$module/" /tmp/production_files.txt)
    if [ -n "$MODULE_FILES" ]; then
        echo "$MODULE_FILES" | while read file; do
            git blame --line-porcelain "$file" 2>/dev/null | grep "^author "
        done | sort | uniq -c | sort -rn | head -5
    fi
done < /tmp/modules.txt
```

### SPOF detection

Flag modules where one person owns >80% of production code (minimum 100 lines).

### Ownership vs Activity Matrix

| Category | Ownership | Activity | Meaning |
|----------|-----------|----------|---------|
| Maintained | HIGH | HIGH | Healthy |
| Abandoned | HIGH | LOW | Risk |
| Transitioning | LOW | HIGH | Knowledge transfer |
| Stable | LOW | LOW | Mature, shared |

## Tool Separation

- **Platform CLI** (`gh`/`glab`): Get commit lists, PR/MR counts, review counts, user lookup
- **Local `git`**: Read commit diffs, blame, shortlog from cloned repo (faster, no rate limits)
- Use CLI to discover what to analyze, use local repo to read the actual code

## Recovery

- If agent fails: halve the batch size
- If session exhausted: check which findings files exist, resume from first gap
- Track SHAs read: write `USERNAME-QN-shas-read.txt` alongside findings
- **Never skip** — coverage gaps must be filled

## Periodic Saving Integration

After each phase completes, save a checkpoint. See `periodic-saving.md` for the full protocol.

```bash
# After Phase 3 (all diffs read for one engineer):
./scripts/checkpoint.sh save contributors/@USERNAME

# After Phase 6 (report generated):
./scripts/checkpoint.sh save contributors/@USERNAME
```

This enables resume from any phase if the session is interrupted.

## API Rate Limits

Platform CLIs (`gh`/`glab`) are subject to API rate limits. Local `git` operations have no limits — this is why the skill uses local git for diff reading and CLI only for metadata.

### Rate Limits by Platform

| Platform | Limit | Reset |
|----------|-------|-------|
| GitHub (authenticated) | 5,000 requests/hour | Rolling window |
| GitHub (`gh search`) | 30 requests/minute | Per-minute window |
| GitLab (authenticated) | 2,000 requests/minute | Per-minute window |

### Check Before Heavy Operations

```bash
# GitHub — check remaining quota
gh api rate_limit --jq '.resources.core.remaining'
# Full breakdown:
gh api rate_limit --jq '.resources | to_entries[] | "\(.key): \(.value.remaining)/\(.value.limit)"'

# GitLab — check from response headers
glab api projects --per-page 1 -i 2>&1 | grep -i "ratelimit-remaining"
```

### Rate-Limit-Safe Patterns

For cross-repo loops (Tier 2-3), add a pause between API calls:

```bash
# GitHub — safe loop with rate limit check
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    # Check remaining before each call
    REMAINING=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "999")
    if [ "$REMAINING" -lt 10 ]; then
        RESET=$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null)
        WAIT=$((RESET - $(date +%s)))
        echo "Rate limited. Saving progress. Waiting ${WAIT}s..."
        # Save partial results before waiting
        ./scripts/checkpoint.sh save codebase
        sleep "$WAIT"
    fi
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | keys[]' 2>/dev/null
done

# GitLab — pause between calls (safe default)
for project_id in $(glab project list --group GROUP --per-page 50 -o json | jq '.[].id'); do
    glab api "projects/$project_id/repository/files/package.json/raw?ref=main" 2>/dev/null | \
      jq -r '.dependencies | keys[]' 2>/dev/null
    sleep 0.5  # Respect GitLab rate limits
done
```

### Pause and Resume on Rate Limit

If rate-limited mid-analysis:

1. **Save checkpoint immediately** — `./scripts/checkpoint.sh save <path>`
2. **Record progress** — write processed repo list to `$PROJECT/.cca/codebase/.repos_processed.txt`
3. **Wait for reset** — GitHub resets hourly, GitLab resets per-minute
4. **Resume** — `./scripts/checkpoint.sh resume <path>`, skip already-processed repos

```bash
# Save which repos have been processed (for cross-repo analysis)
echo "$repo" >> "$PROJECT/.cca/codebase/.repos_processed.txt"

# On resume, skip already-processed repos
PROCESSED="$PROJECT/.cca/codebase/.repos_processed.txt"
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    grep -qx "$repo" "$PROCESSED" 2>/dev/null && continue
    # ... analyze repo ...
    echo "$repo" >> "$PROCESSED"
done
```

### Contributor Analysis Is Mostly Rate-Limit-Free

Phase 2 makes 2-4 CLI calls total (PR counts, review counts). Phases 3-7 use only local `git` — no API calls, no limits. Rate limits only matter for:

- Phase 1: `gh api users/USERNAME` (1 call)
- Phase 2: `gh search prs` (2-4 calls)
- Codebase Tier 2-3: Loop over org repos (N calls per repo)

## Error Handling

- **Can't access repo**: Use `--repo ORG/REPO` with gh, or fall back to local git
- **Too many commits**: Apply batch sizing rules above
- **Agent killed**: Check findings file for partial data, re-launch for remaining SHAs
- **Multiple identities**: Use `--author=email1` OR `--author=email2`
- **Rate limited**: Save checkpoint, wait for reset, resume from last processed item
