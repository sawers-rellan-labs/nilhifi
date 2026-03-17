# Claude Code HPC Setup Guide

Setup and troubleshooting for running Claude Code on the nilhifi project
at NCSU HPC. Based on issues encountered on 2026-03-11.

## Sandbox Permissions

Claude Code's sandbox restricts filesystem writes and network access by default.
On NCSU HPC, LSF commands (`bsub`, `bjobs`, etc.) and network access to the LSF
master need to be explicitly allowed.

### Quick setup with `fix_claude_settings.sh`

The script `docs/claude_code_hpc_setup.sh` writes the correct sandbox configuration
for the VCL HPC environment. Run it once (or after any settings reset):

```bash
cd /rsstu/users/r/rrellan/tlaloc/nilhifi
bash docs/claude_code_hpc_setup.sh
# Then restart Claude Code
```

The script backs up the existing `.claude/settings.json` to `.claude/settings.json.bak`
before overwriting.

### What the settings do

The script writes `.claude/settings.json` with:

| Setting | Value | Purpose |
|---------|-------|---------|
| `sandbox.enabled` | `true` | Keep sandbox active for safety |
| `sandbox.autoAllowBashIfSandboxed` | `true` | Auto-approve bash commands within sandbox restrictions (no manual prompts) |
| `sandbox.excludedCommands` | `bjobs:*`, `bpeek:*`, `bsub:*`, `bhist:*`, `bkill:*`, `bqueues:*`, `conda:*` | LSF commands bypass the sandbox — they need `/tmp` writes and network access that the sandbox blocks. Conda bypasses the sandbox — it needs to write to package cache and env directories outside the project. |
| `sandbox.network.allowedDomains` | `servlsf`, `10.1.16.42`, `github.com` | Allow network to LSF master (hostname + IP) and GitHub |

### Why LSF commands must be excluded

LSF commands (`bsub`, `bjobs`, etc.) write temporary files to `/tmp` and connect
to the LSF master (`servlsf` / `10.1.16.42`). The sandbox blocks both operations:

- **Filesystem:** `bsub` fails with `Read-only file system. Job not submitted.`
- **Network:** `bjobs` fails with `Network is unreachable` (cannot reach LSF master)

`excludedCommands` makes these commands run outside the sandbox entirely, solving both issues.

### Why conda must be excluded

Conda writes to package cache (`/share/maize/frodrig4/conda/pkgs`) and environment
directories (`/share/maize/frodrig4/conda/env/`) which are outside the sandbox's
allowed write paths. Without exclusion, `conda install` / `conda create` fails with
`NoWritablePkgsDirError`.

### Manual fallback

If the script is not available, you can copy the settings manually:

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": [
      "bjobs:*", "bpeek:*", "bsub:*",
      "bhist:*", "bkill:*", "bqueues:*",
      "conda:*"
    ],
    "network": {
      "allowedDomains": ["servlsf", "10.1.16.42", "github.com"]
    }
  }
}
```

Save to `/rsstu/users/r/rrellan/tlaloc/nilhifi/.claude/settings.json` and restart Claude Code.

## Git Identity

Claude cannot commit without git identity configured in the repo:

```bash
cd /rsstu/users/r/rrellan/tlaloc/nilhifi
git config user.email "frodrig4@ncsu.edu"
git config user.name "Fausto Rodriguez Zapata"
```

Without this, `git commit` fails with `Author identity unknown`.

## Git Push Authentication

The remote is HTTPS (`https://github.com/sawers-rellan-labs/nilhifi.git`).
Claude cannot push because there are no cached credentials and `gnome-ssh-askpass`
cannot prompt without a display. SSH keys are also not configured for GitHub
(`Permission denied (publickey)`).

### Install GitHub CLI (recommended)

gh is installed in the `claude-code` conda environment:

```bash
conda activate /share/maize/frodrig4/conda/env/claude-code
gh --version
```

If missing, install with:

```bash
conda install -c conda-forge gh -y
```

### Configure GH_CONFIG_DIR (required on VCL)

`/home` is mounted read-only on NCSU HPC, so `gh` cannot write its auth token
to the default `~/.config/gh/`. Set `GH_CONFIG_DIR` to a persistent writable
location shared across all projects:

```bash
export GH_CONFIG_DIR="/share/maize/frodrig4/.gh"
```

Add this export to your shell profile on the persistent mount (e.g.
`/share/maize/frodrig4/.bashrc_hpc` sourced from `.bashrc`) so it persists
across VCL sessions.

### Authenticate

```bash
export GH_CONFIG_DIR="/share/maize/frodrig4/.gh"
gh auth login --hostname github.com --git-protocol https --web
```

On terminal-only SSH sessions, `xdg-open` will fail to open a browser — this is
expected. The workflow is:

1. `gh` prints a one-time code (e.g. `F89E-8565`) and prompts you to press Enter
2. After pressing Enter, you'll see `xdg-open: no method available` errors — ignore these
3. Open `https://github.com/login/device` manually on any browser (laptop, phone)
4. Log in to GitHub and enter the one-time code
5. Come back to the terminal and press Enter

Expected terminal output on success:

```
✓ Authentication complete.
- gh config set -h github.com git_protocol https
✓ Configured git protocol
! Authentication credentials saved in plain text

✓ Logged in as faustovrz
```

This stores the token in `/share/maize/frodrig4/.gh/` and sets up credential
caching for both `gh` and `git push` across all projects.

### Alternative: switch to SSH remote

```bash
# If you have an SSH key registered with GitHub:
git remote set-url origin git@github.com:sawers-rellan-labs/nilhifi.git
```

### Alternative: personal access token

```bash
git config credential.helper store
git push   # enter username + token when prompted (one time)
```

### Practical workflow

Claude can `git commit` but not `git push`. Let Claude commit, then push yourself.

## Debugging Pipeline Runs

### Per-task log files

Each Nextflow task has a work directory under `nextflow/work/<hash>/`:

| File | What it contains |
|------|------------------|
| `.command.log` | **LSF resource usage summary** (Max Memory, CPU time, wall time). Best source for actual memory consumed. |
| `.command.trace` | Nextflow memory watcher output (peak_rss, peak_vmem in KB, polled periodically). Can differ from LSF numbers. |
| `.command.err` | Task stderr — tool-specific logs (ragtag, minimap2, hifiasm output). |
| `.command.out` | Task stdout. |
| `.command.run` | LSF batch script with `#BSUB` directives — shows what resources were requested. |
| `.command.sh` | The actual shell commands that executed. |

### Pipeline-level logs

| File | What it contains |
|------|------------------|
| `nextflow/nil_pipeline_<JOBID>.out` | Orchestrator output — shows which tasks ran/cached/failed and maps hash→process name. Also has the **orchestrator's** LSF resource summary (not the individual tasks). |
| `nextflow/nil_pipeline_<JOBID>.err` | Orchestrator stderr. |
| `nextflow/.nextflow.log` | Nextflow engine log — scheduling, caching, error details. |

### Finding which work dir belongs to which task

The `nil_pipeline_<JOBID>.out` file maps hashes to process names:

```
[d3/19fef5] Submitted process > RAGTAG_SCAFFOLD_B73 (TMEX_inv4m_B73)
[f1/9a5aaf] Submitted process > RAGTAG_SCAFFOLD_PT (TMEX_inv4m_PT)
```

Then check `nextflow/work/d3/19fef56e.../.command.log` for that task's resource usage.

### Checking memory usage

```bash
# LSF resource summary (at bottom of .command.log):
tail -20 nextflow/work/d3/19fef56e4056680c500f26c468b17a/.command.log

# Nextflow trace (peak_rss in KB):
cat nextflow/work/d3/19fef56e4056680c500f26c468b17a/.command.trace
```

### HTML reports

Nextflow generates these each run (overwritten):

- `results/pipeline_info/report.html` — per-task resource usage, durations
- `results/pipeline_info/timeline.html` — Gantt chart of execution

## Errors Encountered — 2026-03-11

| Error | Root cause | Fix |
|-------|-----------|-----|
| `Author identity unknown` on `git commit` | No `user.email`/`user.name` in repo | `git config user.email` and `git config user.name` |
| `unable to read askpass response` / `could not read Username` on `git push` | No HTTPS credentials, no display for prompt | Install `gh` CLI and run `gh auth login`, or use SSH key |
| `Permission denied (publickey)` on `ssh -T git@github.com` | No SSH key registered with GitHub | Use HTTPS with `gh auth login` instead, or add SSH key |
| `gh: command not found` | GitHub CLI not installed | `conda install -c conda-forge gh` |
| `NoWritablePkgsDirError` from conda | Sandbox blocks writes to `/share/maize/frodrig4/conda/pkgs` | Run `bash docs/claude_code_hpc_setup.sh` — adds `conda:*` to `excludedCommands` |
| `Read-only file system. Job not submitted.` from bsub | Sandbox blocks `/tmp` writes needed by LSF internals | Run `bash docs/claude_code_hpc_setup.sh` — adds `bsub:*` to `excludedCommands` |
| `Network is unreachable` from bjobs | Sandbox blocks network to LSF master | Run `bash docs/claude_code_hpc_setup.sh` — adds `servlsf`/`10.1.16.42` to `allowedDomains` |
