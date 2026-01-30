---
title: Periodic Saving & Checkpoint System
impact: CRITICAL
tags: checkpoint, resume, jsonl, incremental, periodic-saving
---

# Periodic Saving & Checkpoint System

Incremental checkpoint system enabling analysis to survive session interruptions, resume from any phase, and accumulate findings over time without re-reading already-analyzed commits.

## Design Principles

1. **Append-only writes** — never read-modify-write; always append new entries
2. **Schema-first JSONL** — first line of every `.jsonl` file declares the schema
3. **Timestamp everything** — every entry has an ISO 8601 timestamp
4. **Resume from gap** — on restart, find last checkpoint and continue from there
5. **Human-readable snapshots** — JSONL for machines, markdown for humans

## Directory Layout

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
│   ├── relationships.json            # Cross-repo relationships
│   └── .last_analyzed               # Timestamp
├── governance/
│   ├── portfolio.json                # Technology portfolio
│   ├── debt-registry.json            # Technical debt items
│   ├── security-audit.json           # Last security findings
│   └── .last_analyzed
└── .cca-config.json        # Skill configuration
```

## JSONL Format

### Schema-First Pattern

The first line of every `.jsonl` file is a schema declaration:

```jsonl
{"_schema":"contributor-profile","version":"2.0","fields":["type","timestamp","period","data"]}
{"type":"metrics","timestamp":"2025-01-15T10:30:00Z","period":"2025","data":{"commits":413,"prs":89,"reviews":42,"lines_added":45000,"lines_removed":12000}}
{"type":"accuracy","timestamp":"2025-01-15T11:00:00Z","period":"2025","data":{"total_commits":413,"fix_related":91,"accuracy_rate":77.97,"self_reverts":3,"same_day_fixes":42}}
{"type":"quality","timestamp":"2025-01-15T11:30:00Z","period":"2025-Q1","data":{"anti_patterns":{"debug_code":3,"empty_catch":1},"strengths":{"defensive_programming":12,"code_reduction":5}}}
{"type":"review","timestamp":"2025-01-15T12:00:00Z","period":"2025","data":{"level":"Exceeds Expectations","recommendation":"PROMOTE_WITH_GROWTH_PLAN","file":"latest-review.md"}}
```

### Why JSONL

- **Append-only**: No read-modify-write race conditions
- **Schema-first**: Agents can read line 1 to understand the format
- **Streamable**: Read line-by-line without loading entire file
- **Resumable**: Last line = latest state; no need to parse everything
- **Diffable**: Each line is a complete record; git diffs are meaningful

## .last_analyzed Format

Simple text file with two lines:

```
2025-01-15T12:00:00Z
abc1234def5678
```

Line 1: ISO 8601 timestamp of last analysis completion
Line 2: Last git SHA analyzed (for contributors) or "full" (for codebase)

## Checkpoint Protocol

### Save After Each Phase

```bash
# After contributor Phase 2 (metrics gathered)
echo '{"type":"metrics","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","period":"2025","data":{...}}' \
  >> "$PROJECT/.cca/contributors/@username/profile.jsonl"

# After contributor Phase 3 (diffs read for a quarter)
cp SCRATCHPAD/username-Q1-findings.md \
  "$PROJECT/.cca/contributors/@username/checkpoints/2025-Q1.md"

# After contributor Phase 6 (report generated)
cp OUTPUT/username-2025-review.md \
  "$PROJECT/.cca/contributors/@username/latest-review.md"

# Update last analyzed
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROJECT/.cca/contributors/@username/.last_analyzed"
git log --author="EMAIL" -1 --format="%H" >> "$PROJECT/.cca/contributors/@username/.last_analyzed"
```

### Resume Protocol

**MANDATORY: Run `check` before every analysis.** This prevents re-analyzing already-processed commits.

```bash
./scripts/checkpoint.sh check contributors/@USERNAME --author EMAIL
```

| Output | Action |
|--------|--------|
| `FRESH` | No prior analysis — run full Phases 1-7 |
| `CURRENT` | Already analyzed, no new commits — **skip entirely** |
| `INCREMENTAL` | New commits exist — analyze only `LAST_SHA..HEAD`, append to profile |

The `check` command outputs machine-readable key=value pairs:

```
INCREMENTAL
status=incremental
last_sha=abc1234
last_analyzed=2025-06-15T10:30:00Z
new_commits=27
```

For `INCREMENTAL`, use `last_sha` as the starting point:

```bash
# Only read diffs after the last checkpoint
git log --author="EMAIL" LAST_SHA..HEAD --format="%H"
```

Apply batch sizing rules to `new_commits` count only. Append new findings to existing `profile.jsonl` — never overwrite prior entries.

### Manual Resume (Fallback)

If `check` is unavailable, read `.last_analyzed` directly:

```bash
if [ -f "$PROJECT/.cca/contributors/@username/.last_analyzed" ]; then
    LAST_TIMESTAMP=$(head -1 "$PROJECT/.cca/contributors/@username/.last_analyzed")
    LAST_SHA=$(tail -1 "$PROJECT/.cca/contributors/@username/.last_analyzed")
    NEW_COMMITS=$(git log --author="EMAIL" "$LAST_SHA"..HEAD --oneline | wc -l)

    if [ "$NEW_COMMITS" -eq 0 ]; then
        echo "No new commits — analysis is current"
    else
        echo "Resuming from $LAST_SHA — $NEW_COMMITS new commits"
    fi
else
    echo "No prior analysis found — starting fresh"
fi
```

### Incremental Update Flow

For subsequent analyses (not first-time):

1. Read `.last_analyzed` to get last SHA
2. Count new commits since that SHA
3. Apply batch sizing rules (see `contributor-analysis.md`)
4. Analyze only new diffs
5. Calculate period accuracy (new commits only)
6. Append new metrics to `profile.jsonl`
7. Create checkpoint snapshot
8. Update `.last_analyzed` with current HEAD

## Configuration File

`.cca-config.json`:

```json
{
  "version": "2.0",
  "repo": "org/repo-name",
  "org": "org-name",
  "created_at": "2025-01-15T10:00:00Z",
  "contributors_tracked": ["@alice", "@bob", "@charlie"],
  "default_branch": "main",
  "critical_paths": [
    "src/modules/payment",
    "src/modules/orders",
    "src/modules/auth"
  ],
  "excluded_paths": [
    "__tests__",
    "*.test.*",
    "docs/",
    "*.md"
  ]
}
```

## Helper Script

The `scripts/checkpoint.sh` script provides CLI access to checkpoint operations. See the script for full usage.

```bash
# Save checkpoint for a contributor
./scripts/checkpoint.sh save contributors/@alice

# Resume analysis
./scripts/checkpoint.sh resume contributors/@alice

# Show all checkpoint statuses
./scripts/checkpoint.sh status

# Initialize config
./scripts/checkpoint.sh init --repo org/repo --org org-name
```

## Integration With Analysis Phases

| Phase | What Gets Saved | Where |
|-------|----------------|-------|
| Phase 2: Metrics | Commit counts, PR counts, lines | `profile.jsonl` (type: metrics) |
| Phase 3: Diff Reading | Quarterly findings | `checkpoints/YYYY-QN.md` |
| Phase 4: Accuracy | Bug counts, accuracy rate | `profile.jsonl` (type: accuracy) |
| Phase 5: Quality | Anti-patterns, strengths | `profile.jsonl` (type: quality) |
| Phase 6: Report | Full annual review | `latest-review.md` |
| Phase 7: Comparison | Multi-engineer comparison | Project root |
| Codebase: Structure | Module map, architecture | `codebase/structure.json` |
| Codebase: Cross-Repo | Dependency graph | `codebase/dependencies.json` |
| Governance: All | Portfolio, debt, security | `governance/*.json` |

## Rate Limit Pause and Resume

API rate limits can interrupt analysis mid-phase. The checkpoint system handles this:

### Automatic Progress Tracking

Cross-repo operations (Tier 2-3) track processed repos in `.repos_processed.txt`:

```bash
$PROJECT/.cca/codebase/.repos_processed.txt   # One repo name per line
```

On resume, already-processed repos are skipped. No work is repeated.

### Rate Limit Recovery Flow

```
1. API returns 429 or remaining quota < 10
2. Save checkpoint immediately (./scripts/checkpoint.sh save <path>)
3. Record which items have been processed
4. Wait for rate limit reset
5. Resume — checkpoint + progress file = skip completed work
```

### Check Rate Limit Status

```bash
# GitHub
./scripts/checkpoint.sh ratelimit

# Manual check
gh api rate_limit --jq '.resources | to_entries[] | "\(.key): \(.value.remaining)/\(.value.limit)"'
```

## Querying Saved State

```bash
# Get latest accuracy for a contributor
tail -n +2 "$PROJECT/.cca/contributors/@alice/profile.jsonl" | \
  grep '"type":"accuracy"' | tail -1 | jq '.data.accuracy_rate'

# List all tracked contributors
ls "$PROJECT/.cca/contributors/"

# Get last analysis time for codebase
cat "$PROJECT/.cca/codebase/.last_analyzed"

# Count total analysis runs for a contributor
wc -l < "$PROJECT/.cca/contributors/@alice/profile.jsonl"
# (subtract 1 for schema line)
```
