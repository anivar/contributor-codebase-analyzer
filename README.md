<p align="center">
  <img src="assets/logo.svg" alt="Contributor Codebase Analyzer" width="120" height="120"/>
</p>

<h1 align="center">Contributor Codebase Analyzer</h1>

<p align="center">
  <em>Read every commit. Grow every engineer.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0.0-e8a87c?style=flat-square" alt="Version 3.0.0"/>
  <img src="https://img.shields.io/badge/agent_skill-agentic-85dcb0?style=flat-square" alt="Agent Skill"/>
  <img src="https://img.shields.io/badge/license-MIT-e8a87c?style=flat-square" alt="MIT License"/>
  <img src="https://img.shields.io/badge/platform-GitHub_%7C_GitLab-85dcb0?style=flat-square" alt="GitHub | GitLab"/>
  <img src="https://img.shields.io/badge/analysis-every_commit-e8a87c?style=flat-square" alt="Every Commit"/>
  <img src="https://img.shields.io/badge/approach-constructive-85dcb0?style=flat-square" alt="Constructive"/>
</p>

---

Stop guessing about engineering growth. This Agent Skill reads **every commit diff** — not a sample — to give you evidence-backed contributor reviews, codebase health reports, and development recommendations.

## The Problem

Engineering reviews rely on commit counts, PR numbers, and manager impressions. These miss what matters: **code quality, accuracy, growth trajectory, and architectural thinking.**

Manual code review of a year's work is impractical. A single engineer can produce 300-500 commits per year across dozens of modules.

## The Solution

This skill automates deep-dive analysis by:

- Reading every commit diff for each contributor
- Calculating an **accuracy rate** (how often code ships without needing fixes)
- Detecting anti-patterns and strengths from actual code changes
- Generating structured growth reviews with development recommendations
- Mapping codebase structure, cross-repo dependencies, and technical debt

All analysis saves incrementally — interrupt and resume anytime without losing progress.

## Real-World Results

Built and validated analyzing **1,091 commits across 3 staff engineers** in a React Native codebase:

- Found accuracy rates ranging from 78% to 92% across engineers
- Identified production ownership gaps (single points of failure)
- Generated evidence-backed development recommendations with specific commit references
- Completed full analysis with quarterly breakdowns and comparison reports

## Getting Started

### 1. Prerequisites

- `git` (required)
- `gh` — GitHub CLI (required for GitHub repos)
- `glab` — GitLab CLI (required for GitLab repos)
- `jq` and `bc` (optional, for structured output and calculations)

### 2. Install

```bash
git clone https://github.com/anivar/contributor-codebase-analyzer.git
ln -s "$(pwd)/contributor-codebase-analyzer" ~/.claude/skills/contributor-codebase-analyzer
```

### 3. Onboard

Navigate to your project and run:

```bash
./scripts/checkpoint.sh onboard
```

This auto-detects your platform (GitHub/GitLab), repo, and org. No manual configuration needed.

### 4. Use

```
"Analyze github.com/alice-dev for 2025 annual review in repo org/repo"

"Compare github.com/alice-dev and github.com/bob-eng for 2025. Who should be promoted?"

"Analyze the codebase structure of this repo"

"Map dependencies across all repos in our org"

"Run a governance analysis: tech portfolio, debt registry, security posture"
```

## What You Get

### Contributor Reviews

- **Accuracy rate**: `100% - (fix-related commits / total commits)` — a baseline that surfaces where to look deeper
- **Anti-pattern detection**: debug code shipped, empty catch blocks, hook bypass, mega-commits
- **Strength identification**: defensive programming, offline-first design, code reduction, feature gating
- **Quarter-by-quarter breakdown**: growth trajectory, complexity trends, domain breadth
- **Development assessment**: readiness signals, growth areas, and next-level plan
- **Multi-engineer comparison**: complementary strengths with contextual evidence

### Codebase Reports

- **Repository structure**: module map, entry points, architecture patterns, dependencies
- **Cross-repo relationships**: shared libraries, internal packages, dependency graph
- **Enterprise governance**: technology portfolio, technical debt registry, security posture

### Periodic Checkpoints

All work saves to `$PROJECT/.cca/` in append-only JSONL format. Resume from any phase — never re-analyze what's already been processed.

## Platform Support

Works with both **GitHub** and **GitLab** (including nested subgroups). Platform is auto-detected from your git remote URL.

| Feature | GitHub | GitLab |
|---------|--------|--------|
| PR/MR metadata | `gh` CLI | `glab` CLI |
| Code analysis | Local `git` | Local `git` |
| Org discovery | `gh repo list` | `glab project list` |

## How It Works

The skill follows a 7-phase process for contributor analysis:

1. **Identity Discovery** — finds all git email variants automatically
2. **Metrics** — commits, PRs/MRs, reviews, lines changed
3. **Read ALL Diffs** — quarterly parallel agents with batch sizing to prevent failures
4. **Bug Introduction** — self-reverts, crash-fixes, same-day fixes, hook bypass
5. **Code Quality** — anti-patterns and strengths from actual diffs
6. **Report Generation** — structured markdown with ratings and development assessment
7. **Comparison** — multi-engineer strengths comparison with evidence

Batch sizing is enforced from hard limits discovered in production:

| Commits per batch | Strategy |
|-------------------|----------|
| 1-40 | Direct read |
| 41-70 | Single agent |
| 71-90 | 2 parallel agents |
| 91+ | 3+ agents or monthly splits |

## Project Structure

```
├── SKILL.md              # Agent entry point and routing
├── AGENTS.md             # Full compiled guide for agents
├── assets/
│   └── logo.svg          # Project logo
├── references/           # Progressive disclosure by topic
│   ├── onboarding.md
│   ├── contributor-analysis.md
│   ├── accuracy-analysis.md
│   ├── code-quality-catalog.md
│   ├── qualitative-judgment.md
│   ├── report-templates.md
│   ├── codebase-analysis.md
│   └── periodic-saving.md
├── scripts/
│   └── checkpoint.sh     # Save/resume/status/ratelimit helper
└── LICENSE
```

## Design Decisions

**Why every commit, not sampling?**
Sampling misses the story. An engineer's best work might be a 12-line fix that prevents a payment double-charge. Sampling skips it. Reading every diff is what experienced code reviewers do — we encoded that expertise into a repeatable process.

**Why periodic saving?**
AI agents have finite context windows. Analyzing 400+ commits across 12 months can't fit in a single session. Periodic saving to `.cca/` with JSONL append-only profiles lets analysis span multiple agent sessions — picking up exactly where the previous one left off, never re-reading what's already understood.

**Why quality checks, not scores?**
Numbers like commit counts, lines changed, or accuracy rates aren't evaluations — they're **baselines that surface where to look**. A low accuracy rate doesn't mean a bad engineer — it means "look closer at what's happening here." Maybe they own the riskiest module. Maybe they're fixing inherited bugs. The qualitative analysis — reading the actual diffs, understanding the context, assessing the judgment — is what matters. Numbers open the door. Human expertise walks through it.

**Why constructive framing?**
Coming from a FOSS background, `git blame` is a neutral tool — it maps knowledge, not fault. Every label, every comparison, every recommendation is framed for growth: "Developing" not "Below Expectations," "Growth Areas" not "Blockers," strengths before concerns. The fairness checks aren't afterthoughts — they're load-bearing.

**Why both GitHub and GitLab?**
Enterprise teams don't live on one platform. GitLab's nested subgroups, self-hosted instances, and different API patterns required separate handling. Auto-detection from `git remote -v` means zero configuration — the skill adapts to whatever the team uses.

## Constructive Use

This tool reads code to **grow engineers**, not judge them.

**Do:**
- Use findings to start development conversations, not deliver verdicts
- Share reports WITH the engineer, not just about them
- Recognize strengths before discussing growth areas
- Consider context: deadlines, on-call, team changes, unfamiliar codebases
- Use `git blame` for knowledge mapping, not fault-finding

**Don't:**
- Use metrics to justify termination without human context
- Compare engineers as a ranking exercise — compare for complementary strengths
- Treat anti-patterns as character flaws — they're often process or tooling gaps
- Share individual accuracy rates publicly or competitively
- Run analysis without the engineer's awareness

**Fairness checks built in:**
- Same time window and scope for all contributors
- Fix-related commits analyzed for root cause (inherited bug vs introduced)
- Low-activity periods flagged for context (leave, onboarding, cross-team work)
- "Peak then decline" flagged as "support needed," not penalized
- All labels are growth-oriented: "Developing" not "Below Expectations"

## License

MIT
