---
title: Codebase & Enterprise Analysis
impact: HIGH
tags: repo-structure, cross-repo, governance, dependencies, tech-debt, security
---

# Codebase & Enterprise Analysis

Three-tier analysis system for repository structure, cross-repo relationships, and enterprise governance. Complements contributor analysis by answering "what is built" rather than "who built it."

## Tier 1: Repository Structure

Map the internals of a single repository.

### Module Discovery

```bash
# Source file types and counts
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rs" \) | \
  sed 's|.*/||' | sed 's/.*\.//' | sort | uniq -c | sort -rn

# Module map (2 levels deep)
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) | \
  sed 's|^\./||;s|/[^/]*$||' | sort -u | head -50

# Entry points
find . -name "index.ts" -o -name "index.tsx" -o -name "main.ts" \
  -o -name "App.tsx" -o -name "app.ts" | head -20

# Configuration files
find . -maxdepth 2 -name "*.config.*" -o -name ".eslintrc*" \
  -o -name "tsconfig*" -o -name "babel.config*" | sort
```

### Dependency Analysis

```bash
# Direct dependencies
cat package.json | jq -r '.dependencies | keys[]' 2>/dev/null | sort

# Dev dependencies
cat package.json | jq -r '.devDependencies | keys[]' 2>/dev/null | sort

# Dependency version freshness
cat package.json | jq '.dependencies' 2>/dev/null

# Internal imports (find tightly coupled modules)
grep -rn "from '\.\." --include="*.ts" --include="*.tsx" | \
  sed 's/:.*from//;s/['"'"'"]//g' | \
  awk -F: '{print $1, $2}' | sort | head -30
```

### Architecture Patterns

```bash
# Detect common patterns
[ -d "src/components" ] && echo "Component-based architecture"
[ -d "src/hooks" ] && echo "Custom hooks pattern"
[ -d "src/store" ] || [ -d "src/redux" ] && echo "Central state management"
[ -d "src/graphql" ] || [ -d "src/api" ] && echo "API layer abstraction"
[ -d "src/modules" ] || [ -d "AppModules" ] && echo "Module-based architecture"
[ -f "src/navigation" ] || [ -d "src/navigation" ] && echo "Navigation layer"
```

### Output: structure.json

```json
{
  "repo": "org/repo-name",
  "analyzed_at": "2025-01-15T10:30:00Z",
  "language_breakdown": {"typescript": 450, "javascript": 30},
  "modules": [
    {"path": "src/modules/payment", "files": 42, "lines": 3200},
    {"path": "src/modules/orders", "files": 28, "lines": 2100}
  ],
  "entry_points": ["src/App.tsx", "src/index.ts"],
  "architecture_patterns": ["module-based", "custom-hooks", "graphql-api"],
  "config_files": ["tsconfig.json", "babel.config.js"],
  "test_coverage": {"test_files": 120, "source_files": 450}
}
```

## Tier 2: Cross-Repo Relationships

Map how multiple repositories in an organization relate to each other.

**GitLab note:** GitLab supports nested subgroups (e.g., `org/team/subteam/project`). Use `--include-subgroups` when listing projects to traverse the full hierarchy.

### Discover Org Repos

```bash
# List all org repos
# GitHub:
gh repo list ORG --limit 200 --json name,language,updatedAt,isArchived \
  --jq '.[] | select(.isArchived == false) | "\(.name)\t\(.language)\t\(.updatedAt)"'
# GitLab:
glab project list --group GROUP --include-subgroups --per-page 100 -o json | \
  jq '.[] | "\(.path_with_namespace)\t\(.language)\t\(.last_activity_at)"'

# Find shared dependencies across repos
# GitHub:
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    echo "=== $repo ==="
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | keys[]' 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
# GitLab:
for project_id in $(glab project list --group GROUP --per-page 50 -o json | jq '.[].id'); do
    echo "=== $project_id ==="
    glab api "projects/$project_id/repository/files/package.json/raw?ref=main" 2>/dev/null | \
      jq -r '.dependencies | keys[]' 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
```

### Shared Library Detection

```bash
# Find internal packages (scoped to org)
# GitHub:
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | keys[] | select(startswith("@ORG"))' 2>/dev/null
done | sort | uniq -c | sort -rn
# GitLab:
for project_id in $(glab project list --group GROUP --per-page 50 -o json | jq '.[].id'); do
    glab api "projects/$project_id/repository/files/package.json/raw?ref=main" 2>/dev/null | \
      jq -r '.dependencies | keys[] | select(startswith("@ORG"))' 2>/dev/null
done | sort | uniq -c | sort -rn
```

### Output: dependencies.json

```json
{
  "org": "org-name",
  "analyzed_at": "2025-01-15T10:30:00Z",
  "repos": [
    {"name": "main-app", "language": "TypeScript", "last_updated": "2025-01-10"},
    {"name": "api-server", "language": "TypeScript", "last_updated": "2025-01-12"}
  ],
  "shared_dependencies": [
    {"package": "react", "used_by": ["main-app", "admin-portal"]},
    {"package": "@org/shared-utils", "used_by": ["main-app", "api-server", "admin-portal"]}
  ],
  "internal_packages": ["@org/shared-utils", "@org/ui-components"],
  "dependency_graph": {
    "main-app": ["@org/shared-utils", "@org/ui-components"],
    "api-server": ["@org/shared-utils"]
  }
}
```

## Tier 3: Enterprise Governance

Portfolio-level analysis for technology strategy, debt tracking, and security posture.

### Technology Portfolio

```bash
# Language distribution across org
for repo in $(gh repo list ORG --limit 100 --json name --jq '.[].name'); do
    gh api "repos/ORG/$repo/languages" 2>/dev/null | jq -r 'to_entries[] | "\(.key)\t\(.value)"'
done | awk -F'\t' '{lang[$1]+=$2} END {for(l in lang) print lang[l], l}' | sort -rn

# Framework versions
for repo in $(gh repo list ORG --limit 50 --json name --jq '.[].name'); do
    echo "=== $repo ==="
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | to_entries[] |
      select(.key | test("react|angular|vue|next|express|fastify")) |
      "\(.key): \(.value)"' 2>/dev/null
done
```

### Technical Debt Registry

```bash
# TODO/FIXME/HACK density
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) -exec \
  grep -l "TODO\|FIXME\|HACK\|XXX\|WORKAROUND" {} \; | wc -l

# Categorize debt items
grep -rn "TODO\|FIXME\|HACK\|XXX\|WORKAROUND" \
  --include="*.ts" --include="*.tsx" --include="*.js" | \
  awk -F: '{print $1}' | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -20

# Deprecated dependency usage
cat package.json | jq -r '.dependencies | keys[]' 2>/dev/null | while read dep; do
    npm info "$dep" deprecated 2>/dev/null | grep -v "^$" && echo "  ^^^ $dep is deprecated"
done
```

### Security Posture

```bash
# Known vulnerabilities
npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities'

# Secrets in code (basic scan)
grep -rn "API_KEY\|SECRET\|PASSWORD\|TOKEN" \
  --include="*.ts" --include="*.js" --include="*.env*" \
  --exclude-dir=node_modules | grep -v "process.env" | head -20

# Outdated dependencies
npm outdated --json 2>/dev/null | jq 'to_entries[] |
  select(.value.current != .value.latest) |
  "\(.key): \(.value.current) → \(.value.latest)"'
```

### Output Files

**governance/portfolio.json:**
```json
{
  "org": "org-name",
  "analyzed_at": "2025-01-15T10:30:00Z",
  "languages": {"TypeScript": 85, "JavaScript": 10, "Python": 5},
  "frameworks": {"react-native": "0.79", "react": "18.2", "express": "4.18"},
  "active_repos": 12,
  "archived_repos": 3
}
```

**governance/debt-registry.json:**
```json
{
  "analyzed_at": "2025-01-15T10:30:00Z",
  "total_items": 142,
  "by_type": {"TODO": 89, "FIXME": 32, "HACK": 15, "WORKAROUND": 6},
  "hotspots": [
    {"module": "src/modules/payment", "count": 23},
    {"module": "src/modules/orders", "count": 18}
  ],
  "deprecated_deps": ["left-pad", "request"]
}
```

**governance/security-audit.json:**
```json
{
  "analyzed_at": "2025-01-15T10:30:00Z",
  "vulnerabilities": {"critical": 0, "high": 2, "moderate": 5, "low": 12},
  "outdated_deps": 15,
  "potential_secrets": 0,
  "last_npm_audit": "2025-01-15"
}
```

## IDE Context Generation

Optionally generate `.cursorrules` or similar IDE context files:

```bash
# Generate from structure analysis
echo "This is a $(cat structure.json | jq -r '.architecture_patterns | join(", ")') project."
echo "Key modules: $(cat structure.json | jq -r '.modules[].path' | head -5 | tr '\n' ', ')"
```

## Periodic Saving

All codebase and governance outputs are saved to `.cca/`:

```
$PROJECT/.cca/
├── codebase/
│   ├── structure.json
│   ├── dependencies.json
│   └── .last_analyzed
└── governance/
    ├── portfolio.json
    ├── debt-registry.json
    ├── security-audit.json
    └── .last_analyzed
```

On re-analysis, compare with previous state to show deltas (new debt items, resolved vulnerabilities, etc.).

## API Rate Limits

Tier 2 and Tier 3 analysis loops over org repos via platform CLI — the highest rate limit risk in this skill.

### Rate Limit Budget

| Operation | API Calls | Risk |
|-----------|-----------|------|
| Tier 1 (single repo) | 0 (local git only) | None |
| Tier 2 (50 repos) | 1 list + 50 content fetches | Medium |
| Tier 2 (200 repos) | 1 list + 200 content fetches | High |
| Tier 3 (100 repos, 3 scans) | 1 list + 300 fetches | High |

### Rate-Limit-Safe Cross-Repo Pattern

```bash
# Track progress for pause/resume
PROCESSED="$PROJECT/.cca/codebase/.repos_processed.txt"
touch "$PROCESSED"

for repo in $(gh repo list ORG --limit 100 --json name --jq '.[].name'); do
    # Skip already-processed repos (resume support)
    grep -qx "$repo" "$PROCESSED" 2>/dev/null && continue

    # Check remaining quota
    REMAINING=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "999")
    if [ "$REMAINING" -lt 10 ]; then
        echo "Rate limited after processing $(wc -l < "$PROCESSED") repos. Saving progress..."
        ./scripts/checkpoint.sh save codebase
        RESET=$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null)
        WAIT=$((RESET - $(date +%s)))
        echo "Waiting ${WAIT}s for rate limit reset..."
        sleep "$WAIT"
    fi

    # Analyze repo
    gh api "repos/ORG/$repo/contents/package.json" --jq '.content' 2>/dev/null | \
      base64 -d 2>/dev/null | jq -r '.dependencies | keys[]' 2>/dev/null

    # Record progress
    echo "$repo" >> "$PROCESSED"
done
```

For GitLab, add `sleep 0.5` between API calls to stay within per-minute limits:

```bash
for project_id in $(glab project list --group GROUP --per-page 100 -o json | jq '.[].id'); do
    glab api "projects/$project_id/languages" 2>/dev/null | \
      jq -r 'to_entries[] | "\(.key)\t\(.value)"'
    sleep 0.5
done
```

### Pause and Resume

If rate-limited mid-scan:

1. Progress is tracked in `.repos_processed.txt` — already-scanned repos are skipped on resume
2. Save checkpoint: `./scripts/checkpoint.sh save codebase`
3. Wait for reset (GitHub: ~1 hour, GitLab: ~1 minute)
4. Re-run the same command — it picks up where it left off
