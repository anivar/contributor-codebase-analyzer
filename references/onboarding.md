---
title: Onboarding Guide
impact: SETUP
tags: onboarding, setup, first-run, platform-detection, configuration
---

# Onboarding Guide

First-time setup for contributor-codebase-analyzer. Detects your git platform, configures the skill, and verifies prerequisites.

## Quick Start

```bash
./scripts/checkpoint.sh onboard
```

The onboard command runs all steps automatically. This reference documents what happens and how to do it manually.

## Step 1: Detect Git Platform

```bash
# Read the remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null)

# Detect platform
if echo "$REMOTE_URL" | grep -qiE "github\.com|github\."; then
    PLATFORM="github"
    CLI_TOOL="gh"
elif echo "$REMOTE_URL" | grep -qiE "gitlab\.com|gitlab\."; then
    PLATFORM="gitlab"
    CLI_TOOL="glab"
else
    # Could be self-hosted — check for GitLab API markers
    DOMAIN=$(echo "$REMOTE_URL" | sed -E 's|.*[@/]([^:/]+)[:/].*|\1|')
    if curl -s "https://$DOMAIN/api/v4/version" 2>/dev/null | grep -q "version"; then
        PLATFORM="gitlab"
        CLI_TOOL="glab"
    else
        PLATFORM="github"
        CLI_TOOL="gh"
    fi
fi

echo "Detected platform: $PLATFORM (CLI: $CLI_TOOL)"
```

## Step 2: Extract Repo and Org/Group

```bash
# Parse org/repo from remote URL
# Handles: git@github.com:org/repo.git, https://github.com/org/repo.git
REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+/[^/]+?)(\.git)?$|\1|')
ORG=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_PATH" | cut -d'/' -f2)

echo "Org/Group: $ORG"
echo "Repo: $REPO_NAME"
echo "Full path: $ORG/$REPO_NAME"
```

## Step 3: Verify CLI Tools

```bash
# Check git
git --version || echo "ERROR: git is required"

# Check platform CLI
if [ "$PLATFORM" = "github" ]; then
    gh --version 2>/dev/null || echo "WARNING: gh (GitHub CLI) not installed. PR/MR counts will be unavailable."
    gh auth status 2>/dev/null || echo "WARNING: gh not authenticated. Run: gh auth login"
elif [ "$PLATFORM" = "gitlab" ]; then
    glab --version 2>/dev/null || echo "WARNING: glab (GitLab CLI) not installed. MR counts will be unavailable."
    glab auth status 2>/dev/null || echo "WARNING: glab not authenticated. Run: glab auth login"
fi

# Check optional tools
jq --version 2>/dev/null || echo "NOTE: jq not installed. JSON parsing will use fallback methods."
bc --version 2>/dev/null || echo "NOTE: bc not installed. Accuracy calculations will use awk."
```

## Step 4: Detect Default Branch

```bash
DEFAULT_BRANCH="main"
for branch in main master production prod release; do
    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        DEFAULT_BRANCH="$branch"
        break
    fi
done
echo "Default branch: $DEFAULT_BRANCH"
```

## Step 5: Create Configuration

```bash
mkdir -p "$PROJECT/.cca"/{contributors,codebase,governance}

cat > "$PROJECT/.cca/.cca-config.json" <<EOF
{
  "version": "3.0",
  "platform": "$PLATFORM",
  "cli_tool": "$CLI_TOOL",
  "repo": "$ORG/$REPO_NAME",
  "org": "$ORG",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contributors_tracked": [],
  "default_branch": "$DEFAULT_BRANCH",
  "critical_paths": [],
  "excluded_paths": ["__tests__", "*.test.*", "docs/", "*.md"]
}
EOF
```

## Step 6: Add First Contributor (Optional)

```bash
# Discover contributors from git log (top 10 by commit count)
echo "Top contributors in this repo:"
git shortlog -sn --all | head -10

# To add a contributor:
# Provide their GitHub/GitLab username
# The skill auto-discovers their email variants from git log

# Example: add github.com/alice-dev
USERNAME="alice-dev"
mkdir -p "$PROJECT/.cca/contributors/@$USERNAME"

# Discover their git email(s)
git log --all --format='%ae %an' | sort -u | grep -i "$USERNAME"
```

## Step 7: Verify Setup

```bash
./scripts/checkpoint.sh status
```

Expected output after onboarding:
```
=== Contributor Codebase Analyzer — Checkpoint Status ===

Platform: github (gh)
Repo: org/repo-name | Org: org

Contributors:
  (none tracked yet)

Codebase:
  Status: Not analyzed

Governance:
  Status: Not analyzed
```

## What Happens Next

After onboarding, typical first actions:

1. **Run a contributor analysis:**
   ```
   "Analyze github.com/alice-dev for 2025 annual review in repo org/repo"
   ```

2. **Map the codebase:**
   ```
   "Analyze the codebase structure of this repo"
   ```

3. **Check who's available to analyze:**
   ```bash
   git shortlog -sn --after="2025-01-01" | head -20
   ```

## Platform-Specific Notes

### GitHub

- `gh auth login` for authentication
- `gh search prs` for PR metadata
- `gh api` for raw API access
- Supports organization-level repo listing

### GitLab

- `glab auth login` for authentication
- `glab mr list` for MR metadata
- `glab api` for raw API access
- Uses "groups" instead of "orgs" for multi-repo analysis
- Self-hosted instances: set `GITLAB_HOST` environment variable

### Self-Hosted Instances

For self-hosted GitHub Enterprise or GitLab:

```bash
# GitHub Enterprise
gh auth login --hostname github.yourcompany.com

# GitLab self-hosted
export GITLAB_HOST=gitlab.yourcompany.com
glab auth login --hostname gitlab.yourcompany.com
```

The skill auto-detects self-hosted instances from the git remote URL.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "gh: command not found" | Install: `brew install gh` or see https://cli.github.com |
| "glab: command not found" | Install: `brew install glab` or see https://gitlab.com/gitlab-org/cli |
| "gh auth: not logged in" | Run: `gh auth login` |
| "glab auth: not logged in" | Run: `glab auth login` |
| Wrong platform detected | Edit `.cca/.cca-config.json` manually |
| Self-hosted not detected | Set `GITLAB_HOST` or use `--hostname` flag |
