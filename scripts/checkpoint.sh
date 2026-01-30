#!/usr/bin/env bash
# checkpoint.sh — Periodic save/resume/status/onboard for contributor-codebase-analyzer
# Usage:
#   ./scripts/checkpoint.sh onboard                # First-time setup
#   ./scripts/checkpoint.sh init --repo ORG/REPO [--org ORG] [--platform github|gitlab]
#   ./scripts/checkpoint.sh save <path>            # e.g., contributors/@alice
#   ./scripts/checkpoint.sh resume <path>           # Show resume info
#   ./scripts/checkpoint.sh status                  # Show all checkpoints
#   ./scripts/checkpoint.sh append <path> <json>    # Append to profile.jsonl

set -euo pipefail

# Find project root (walk up to find .git)
find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        [ -d "$dir/.git" ] && echo "$dir" && return 0
        dir=$(dirname "$dir")
    done
    echo "$PWD"
}

PROJECT_ROOT=$(find_project_root)
CA_DIR="$PROJECT_ROOT/.cca"

# Colors (if terminal supports them)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

usage() {
    cat <<EOF
contributor-codebase-analyzer checkpoint manager

Usage:
  $(basename "$0") onboard
  $(basename "$0") init --repo ORG/REPO [--org ORG] [--platform github|gitlab]
  $(basename "$0") check <path> [--author EMAIL]
  $(basename "$0") save <path>
  $(basename "$0") resume <path>
  $(basename "$0") status
  $(basename "$0") ratelimit
  $(basename "$0") append <path> <json-string>

Commands:
  onboard     Interactive first-time setup (auto-detects platform, repo, org)
  init        Initialize .cca/ directory with config
  check       Check if analysis is needed (returns FRESH, CURRENT, or INCREMENTAL)
  save        Update .last_analyzed timestamp and SHA for a path
  resume      Show resume information for a path
  status      Show status of all checkpoints
  ratelimit   Check API rate limit status for current platform
  append      Append a JSON line to a contributor's profile.jsonl

Paths:
  contributors/@username   Contributor checkpoint
  codebase                 Codebase analysis checkpoint
  governance               Governance analysis checkpoint

Examples:
  $(basename "$0") onboard
  $(basename "$0") init --repo myorg/myrepo --org myorg
  $(basename "$0") save contributors/@alice
  $(basename "$0") resume contributors/@alice
  $(basename "$0") status
  $(basename "$0") ratelimit
  $(basename "$0") append contributors/@alice '{"type":"metrics","timestamp":"2025-01-15T10:30:00Z","period":"2025","data":{"commits":413}}'
EOF
}

# Detect git platform from remote URL
detect_platform() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [ -z "$remote_url" ]; then
        echo "unknown"
        return
    fi

    if echo "$remote_url" | grep -qiE "github\.com|github\."; then
        echo "github"
    elif echo "$remote_url" | grep -qiE "gitlab\.com|gitlab\."; then
        echo "gitlab"
    else
        # Try GitLab API probe for self-hosted
        local domain
        domain=$(echo "$remote_url" | sed -E 's|.*[@/]([^:/]+)[:/].*|\1|')
        if curl -s --max-time 3 "https://$domain/api/v4/version" 2>/dev/null | grep -q "version"; then
            echo "gitlab"
        else
            echo "github"
        fi
    fi
}

# Extract org/repo from remote URL
extract_repo_info() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    echo "$remote_url" | sed -E 's|.*[:/]([^/]+/[^/]+?)(\.git)?$|\1|'
}

cmd_onboard() {
    echo -e "${BLUE}=== Contributor Codebase Analyzer — Onboarding ===${NC}"
    echo ""

    # Step 1: Detect platform
    echo -e "${BLUE}Step 1: Detecting git platform...${NC}"
    local platform
    platform=$(detect_platform)

    local cli_tool="gh"
    if [ "$platform" = "gitlab" ]; then
        cli_tool="glab"
    fi
    echo -e "  Platform: ${GREEN}$platform${NC} (CLI: $cli_tool)"

    # Step 2: Extract repo info
    echo ""
    echo -e "${BLUE}Step 2: Identifying repository...${NC}"
    local repo_path org repo_name
    repo_path=$(extract_repo_info)
    org=$(echo "$repo_path" | cut -d'/' -f1)
    repo_name=$(echo "$repo_path" | cut -d'/' -f2)
    echo "  Org/Group: $org"
    echo "  Repo: $repo_name"

    # Step 3: Verify CLI tools
    echo ""
    echo -e "${BLUE}Step 3: Verifying tools...${NC}"
    local cli_ok=true

    if ! git --version >/dev/null 2>&1; then
        echo -e "  ${RED}git: NOT FOUND (required)${NC}"
        cli_ok=false
    else
        echo -e "  git: ${GREEN}OK${NC}"
    fi

    if [ "$platform" = "github" ]; then
        if gh --version >/dev/null 2>&1; then
            echo -e "  gh: ${GREEN}OK${NC}"
            if gh auth status >/dev/null 2>&1; then
                echo -e "  gh auth: ${GREEN}authenticated${NC}"
            else
                echo -e "  gh auth: ${YELLOW}not logged in (run: gh auth login)${NC}"
            fi
        else
            echo -e "  gh: ${YELLOW}not installed (PR/MR counts unavailable)${NC}"
        fi
    elif [ "$platform" = "gitlab" ]; then
        if glab --version >/dev/null 2>&1; then
            echo -e "  glab: ${GREEN}OK${NC}"
            if glab auth status >/dev/null 2>&1; then
                echo -e "  glab auth: ${GREEN}authenticated${NC}"
            else
                echo -e "  glab auth: ${YELLOW}not logged in (run: glab auth login)${NC}"
            fi
        else
            echo -e "  glab: ${YELLOW}not installed (MR counts unavailable)${NC}"
        fi
    fi

    if jq --version >/dev/null 2>&1; then
        echo -e "  jq: ${GREEN}OK${NC}"
    else
        echo -e "  jq: ${YELLOW}optional, not installed${NC}"
    fi

    # Step 4: Detect default branch
    echo ""
    echo -e "${BLUE}Step 4: Detecting default branch...${NC}"
    local default_branch="main"
    for branch in main master production prod release; do
        if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
            default_branch="$branch"
            break
        fi
    done
    echo "  Default branch: $default_branch"

    # Step 5: Create config
    echo ""
    echo -e "${BLUE}Step 5: Creating .cca/ directory...${NC}"
    mkdir -p "$CA_DIR"/{contributors,codebase,governance}

    local config="$CA_DIR/.cca-config.json"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > "$config" <<CONF
{
  "platform": "$platform",
  "cli_tool": "$cli_tool",
  "repo": "$org/$repo_name",
  "org": "$org",
  "created_at": "$timestamp",
  "contributors_tracked": [],
  "default_branch": "$default_branch",
  "critical_paths": [],
  "excluded_paths": ["__tests__", "*.test.*", "docs/", "*.md"]
}
CONF

    echo -e "  ${GREEN}Created $config${NC}"

    # Step 6: Show top contributors
    echo ""
    echo -e "${BLUE}Step 6: Top contributors in this repo:${NC}"
    git shortlog -sn --all 2>/dev/null | head -10 | while read count name; do
        echo "  $count  $name"
    done

    echo ""
    echo -e "${GREEN}=== Onboarding complete ===${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Analyze a contributor:"
    echo "     \"Analyze github.com/USERNAME for 2025 annual review in repo $org/$repo_name\""
    echo "  2. Map the codebase:"
    echo "     \"Analyze the codebase structure of this repo\""
    echo "  3. Check status anytime:"
    echo "     ./scripts/checkpoint.sh status"
}

cmd_init() {
    local repo="" org="" platform=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)     repo="$2"; shift 2 ;;
            --org)      org="$2"; shift 2 ;;
            --platform) platform="$2"; shift 2 ;;
            *)          echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$repo" ]; then
        echo "Error: --repo is required"
        exit 1
    fi

    [ -z "$org" ] && org=$(echo "$repo" | cut -d'/' -f1)
    [ -z "$platform" ] && platform=$(detect_platform)

    local cli_tool="gh"
    [ "$platform" = "gitlab" ] && cli_tool="glab"

    # Detect default branch
    local default_branch="main"
    for branch in main master production; do
        if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
            default_branch="$branch"
            break
        fi
    done

    mkdir -p "$CA_DIR"/{contributors,codebase,governance}

    local config="$CA_DIR/.cca-config.json"
    if [ -f "$config" ]; then
        echo -e "${YELLOW}Config already exists at $config${NC}"
        echo "Updating..."
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > "$config" <<CONF
{
  "platform": "$platform",
  "cli_tool": "$cli_tool",
  "repo": "$repo",
  "org": "$org",
  "created_at": "$timestamp",
  "contributors_tracked": [],
  "default_branch": "$default_branch",
  "critical_paths": [],
  "excluded_paths": ["__tests__", "*.test.*", "docs/", "*.md"]
}
CONF

    echo -e "${GREEN}Initialized .cca/ at $CA_DIR${NC}"
    echo "  Platform: $platform ($cli_tool)"
    echo "  Repo: $repo"
    echo "  Org: $org"
    echo "  Branch: $default_branch"
}

cmd_save() {
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "Error: path required (e.g., contributors/@alice, codebase, governance)"
        exit 1
    fi

    local target_dir="$CA_DIR/$path"
    mkdir -p "$target_dir"

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local last_sha
    last_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    echo "$timestamp" > "$target_dir/.last_analyzed"
    echo "$last_sha" >> "$target_dir/.last_analyzed"

    echo -e "${GREEN}Checkpoint saved:${NC} $path"
    echo "  Timestamp: $timestamp"
    echo "  SHA: $last_sha"

    # If this is a contributor, note tracking
    if [[ "$path" == contributors/@* ]]; then
        local username
        username=$(basename "$path")
        local config="$CA_DIR/.cca-config.json"
        if [ -f "$config" ]; then
            if ! grep -q "\"$username\"" "$config" 2>/dev/null; then
                echo -e "${BLUE}Note: Add $username to contributors_tracked in config${NC}"
            fi
        fi
    fi
}

cmd_check() {
    local path="${1:-}"
    local author="${2:-}"

    if [ -z "$path" ]; then
        echo "Error: path required (e.g., contributors/@alice)"
        echo "Usage: $(basename "$0") check <path> [--author EMAIL]"
        exit 1
    fi

    # Parse --author flag
    if [ "$author" = "--author" ]; then
        author="${3:-}"
    fi

    local target_dir="$CA_DIR/$path"
    local last_analyzed="$target_dir/.last_analyzed"

    # No prior analysis — fresh start
    if [ ! -f "$last_analyzed" ]; then
        echo "FRESH"
        echo "status=fresh"
        echo "last_sha="
        echo "new_commits=all"
        return 0
    fi

    local last_timestamp last_sha
    last_timestamp=$(head -1 "$last_analyzed")
    last_sha=$(tail -1 "$last_analyzed")

    # SHA no longer exists in repo
    if ! git cat-file -t "$last_sha" >/dev/null 2>&1; then
        echo "FRESH"
        echo "status=fresh"
        echo "last_sha=$last_sha"
        echo "reason=sha_not_found"
        return 0
    fi

    # Count new commits since last analysis
    local new_commits
    if [ -n "$author" ]; then
        new_commits=$(git log --author="$author" "$last_sha"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    else
        new_commits=$(git log "$last_sha"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [ "$new_commits" -eq 0 ]; then
        echo "CURRENT"
        echo "status=current"
        echo "last_sha=$last_sha"
        echo "last_analyzed=$last_timestamp"
        echo "new_commits=0"
    else
        echo "INCREMENTAL"
        echo "status=incremental"
        echo "last_sha=$last_sha"
        echo "last_analyzed=$last_timestamp"
        echo "new_commits=$new_commits"
    fi
}

cmd_resume() {
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "Error: path required (e.g., contributors/@alice)"
        exit 1
    fi

    local target_dir="$CA_DIR/$path"
    local last_analyzed="$target_dir/.last_analyzed"

    if [ ! -f "$last_analyzed" ]; then
        echo -e "${YELLOW}No prior analysis found for $path${NC}"
        echo "Starting fresh analysis."
        return 0
    fi

    local last_timestamp last_sha
    last_timestamp=$(head -1 "$last_analyzed")
    last_sha=$(tail -1 "$last_analyzed")

    echo -e "${BLUE}Resume info for $path:${NC}"
    echo "  Last analyzed: $last_timestamp"
    echo "  Last SHA: $last_sha"

    # Check if SHA still exists
    if ! git cat-file -t "$last_sha" >/dev/null 2>&1; then
        echo -e "${RED}  Warning: SHA $last_sha not found in repository${NC}"
        echo "  May need full re-analysis."
        return 1
    fi

    local new_commits
    new_commits=$(git log "$last_sha"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

    echo "  New commits since: $new_commits"

    if [ "$new_commits" -eq 0 ]; then
        echo -e "${GREEN}  Analysis is current — no new work needed${NC}"
    else
        echo -e "${YELLOW}  $new_commits commits need analysis${NC}"
    fi

    # Show existing checkpoints
    if [ -d "$target_dir/checkpoints" ]; then
        local checkpoint_count
        checkpoint_count=$(ls "$target_dir/checkpoints/" 2>/dev/null | wc -l | tr -d ' ')
        echo "  Existing checkpoints: $checkpoint_count"
    fi

    # Show profile entries
    if [ -f "$target_dir/profile.jsonl" ]; then
        local entry_count
        entry_count=$(wc -l < "$target_dir/profile.jsonl" | tr -d ' ')
        entry_count=$((entry_count - 1))  # Subtract schema line
        echo "  Profile entries: $entry_count"
    fi

    # Show if review exists
    if [ -f "$target_dir/latest-review.md" ]; then
        echo -e "  Latest review: ${GREEN}exists${NC}"
    fi
}

cmd_status() {
    if [ ! -d "$CA_DIR" ]; then
        echo -e "${YELLOW}No .cca/ directory found${NC}"
        echo "Run: $(basename "$0") onboard"
        return 0
    fi

    echo -e "${BLUE}=== Contributor Codebase Analyzer — Checkpoint Status ===${NC}"
    echo ""

    # Config
    if [ -f "$CA_DIR/.cca-config.json" ]; then
        local repo org platform
        repo=$(grep '"repo"' "$CA_DIR/.cca-config.json" | sed 's/.*: *"//;s/".*//')
        org=$(grep '"org"' "$CA_DIR/.cca-config.json" | sed 's/.*: *"//;s/".*//')
        platform=$(grep '"platform"' "$CA_DIR/.cca-config.json" | sed 's/.*: *"//;s/".*//' 2>/dev/null || echo "unknown")
        echo "Platform: $platform | Repo: $repo | Org: $org"
        echo ""
    fi

    # Contributors
    if [ -d "$CA_DIR/contributors" ]; then
        echo -e "${BLUE}Contributors:${NC}"
        local found_any=false
        for user_dir in "$CA_DIR/contributors"/@*/; do
            [ -d "$user_dir" ] || continue
            found_any=true
            local username
            username=$(basename "$user_dir")

            if [ -f "$user_dir/.last_analyzed" ]; then
                local ts sha
                ts=$(head -1 "$user_dir/.last_analyzed")
                sha=$(tail -1 "$user_dir/.last_analyzed")
                echo -e "  $username: ${GREEN}OK${NC} (last: $ts, SHA: ${sha:0:7})"
            else
                echo -e "  $username: ${YELLOW}NEW${NC} (no prior analysis)"
            fi

            # Checkpoint count
            if [ -d "$user_dir/checkpoints" ]; then
                local ck_count
                ck_count=$(ls "$user_dir/checkpoints/" 2>/dev/null | wc -l | tr -d ' ')
                [ "$ck_count" -gt 0 ] && echo "    Checkpoints: $ck_count"
            fi

            # Profile entries
            if [ -f "$user_dir/profile.jsonl" ]; then
                local p_count
                p_count=$(wc -l < "$user_dir/profile.jsonl" | tr -d ' ')
                p_count=$((p_count - 1))
                [ "$p_count" -gt 0 ] && echo "    Profile entries: $p_count"
            fi

            # Review
            [ -f "$user_dir/latest-review.md" ] && echo "    Latest review: exists"
        done
        [ "$found_any" = false ] && echo "  (none tracked yet)"
        echo ""
    fi

    # Codebase
    if [ -d "$CA_DIR/codebase" ]; then
        echo -e "${BLUE}Codebase:${NC}"
        if [ -f "$CA_DIR/codebase/.last_analyzed" ]; then
            local ts
            ts=$(head -1 "$CA_DIR/codebase/.last_analyzed")
            echo -e "  Status: ${GREEN}Analyzed${NC} ($ts)"
        else
            echo -e "  Status: ${YELLOW}Not analyzed${NC}"
        fi
        for f in "$CA_DIR/codebase"/*.json; do
            [ -f "$f" ] && echo "    $(basename "$f"): exists"
        done
        echo ""
    fi

    # Governance
    if [ -d "$CA_DIR/governance" ]; then
        echo -e "${BLUE}Governance:${NC}"
        if [ -f "$CA_DIR/governance/.last_analyzed" ]; then
            local ts
            ts=$(head -1 "$CA_DIR/governance/.last_analyzed")
            echo -e "  Status: ${GREEN}Analyzed${NC} ($ts)"
        else
            echo -e "  Status: ${YELLOW}Not analyzed${NC}"
        fi
        for f in "$CA_DIR/governance"/*.json; do
            [ -f "$f" ] && echo "    $(basename "$f"): exists"
        done
    fi
}

cmd_ratelimit() {
    local platform
    platform=$(detect_platform)

    echo -e "${BLUE}=== API Rate Limit Status ===${NC}"
    echo ""

    if [ "$platform" = "github" ]; then
        if ! gh auth status >/dev/null 2>&1; then
            echo -e "${RED}GitHub CLI not authenticated. Run: gh auth login${NC}"
            return 1
        fi

        echo -e "${BLUE}GitHub API Rate Limits:${NC}"
        gh api rate_limit --jq '.resources | to_entries[] | "\(.key): \(.value.remaining)/\(.value.limit) (resets \(.value.reset | todate))"' 2>/dev/null | while read line; do
            local remaining
            remaining=$(echo "$line" | grep -oP '\d+/' | head -1 | tr -d '/')
            if [ -n "$remaining" ] && [ "$remaining" -lt 100 ]; then
                echo -e "  ${RED}$line${NC}"
            elif [ -n "$remaining" ] && [ "$remaining" -lt 500 ]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${GREEN}$line${NC}"
            fi
        done

        echo ""
        echo "Limits: 5,000 requests/hour (core), 30 requests/minute (search)"

    elif [ "$platform" = "gitlab" ]; then
        if ! glab auth status >/dev/null 2>&1; then
            echo -e "${RED}GitLab CLI not authenticated. Run: glab auth login${NC}"
            return 1
        fi

        echo -e "${BLUE}GitLab API Rate Limits:${NC}"
        local headers
        headers=$(glab api projects --per-page 1 -i 2>&1 | grep -i "ratelimit")
        if [ -n "$headers" ]; then
            echo "$headers" | while read line; do
                echo "  $line"
            done
        else
            echo "  Could not retrieve rate limit headers."
            echo "  GitLab limit: 2,000 requests/minute (authenticated)"
        fi

        echo ""
        echo "Limit: 2,000 requests/minute (authenticated)"

    else
        echo -e "${YELLOW}Unknown platform. Cannot check rate limits.${NC}"
        echo "Run: $(basename "$0") onboard"
    fi

    # Show cross-repo progress if exists
    local processed="$CA_DIR/codebase/.repos_processed.txt"
    if [ -f "$processed" ]; then
        local count
        count=$(wc -l < "$processed" | tr -d ' ')
        echo ""
        echo -e "${BLUE}Cross-repo progress:${NC} $count repos processed"
        echo "  File: $processed"
    fi
}

cmd_append() {
    local path="${1:-}"
    local json_line="${2:-}"

    if [ -z "$path" ] || [ -z "$json_line" ]; then
        echo "Error: path and json-string required"
        echo "Usage: $(basename "$0") append contributors/@alice '{\"type\":\"metrics\",...}'"
        exit 1
    fi

    local target_dir="$CA_DIR/$path"
    local profile="$target_dir/profile.jsonl"

    mkdir -p "$target_dir"

    # If profile doesn't exist, write schema line first
    if [ ! -f "$profile" ]; then
        echo '{"_schema":"contributor-profile","fields":["type","timestamp","period","data"]}' > "$profile"
        echo -e "${BLUE}Created new profile: $profile${NC}"
    fi

    echo "$json_line" >> "$profile"
    echo -e "${GREEN}Appended to $profile${NC}"
}

# Main dispatch
case "${1:-}" in
    onboard)   cmd_onboard ;;
    init)      shift; cmd_init "$@" ;;
    check)     shift; cmd_check "$@" ;;
    save)      shift; cmd_save "$@" ;;
    resume)    shift; cmd_resume "$@" ;;
    status)    cmd_status ;;
    ratelimit) cmd_ratelimit ;;
    append)    shift; cmd_append "$@" ;;
    -h|--help|help) usage ;;
    *)
        if [ -z "${1:-}" ]; then
            usage
        else
            echo "Unknown command: $1"
            echo ""
            usage
            exit 1
        fi
        ;;
esac
