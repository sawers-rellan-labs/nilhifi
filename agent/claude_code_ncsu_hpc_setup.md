# Claude Code on NCSU HPC — Setup Guide

## Quick Start (Human Steps)

You need to do these 5 things manually. A Claude agent can handle everything else.

```
1. Install Claude Code:        npm install -g @anthropic-ai/claude-code
2. Store SMB credentials:      Finder → Cmd+K → smb://oitrspprd.hpc.ncsu.edu/rsstu/users/r/YOUR_GROUP
                                → Check "Remember this password in my keychain"
3. Create SSH sockets dir:     mkdir -p ~/.ssh/sockets
4. Prime SSH (Duo 2FA):        ssh hazel   → approve Duo push → exit
5. Start Claude Code:          cd ~/mnt/YOUR_SHARE/YOUR_PROJECT && claude
```

After step 4, Claude Code can run SSH commands for ~60 minutes without Duo prompts.
Repeat step 4 whenever the socket expires (60 min of zero SSH activity).

---

## Architecture Overview

Claude Code runs **locally on a macOS laptop**. It does not run on the HPC cluster.

```
┌─────────────────────┐         SMB (read/write files)        ┌──────────────────────┐
│   Mac Laptop         │ ─────────────────────────────────────→ │  rsstu storage       │
│                     │                                        │  /rsstu/users/r/     │
│   Claude Code       │         SSH (bsub, bjobs, etc.)        │  YOUR_GROUP/         │
│   (local process)   │ ─────────────────────────────────────→ │                      │
│                     │         to login.hpc.ncsu.edu          │  ← HPC nodes also    │
│   Internet access ✓ │                                        │    mount this path    │
└─────────────────────┘                                        └──────────────────────┘
```

- **File I/O** goes through an SMB mount (`~/mnt/YOUR_SHARE` → `/rsstu/users/r/YOUR_GROUP`)
- **HPC commands** go through SSH (`ssh hazel "bsub < script.sh"`)
- **Internet access** is available locally (Anthropic API, web search, docs)
- Same bytes on both sides — no file transfer needed

### Why not run Claude Code on the HPC?

1. **Compute nodes have no internet** — Claude Code needs the Anthropic API
2. **Login nodes** — Claude Code's ~500 MB RSS is non-trivial for shared login nodes; processes using significant resources are terminated without notice per AUP
3. **Interactive session bug** — Claude Code has known stdin issues in `bsub -Is` sessions

### NC State Compliance

- Claude Code is **approved** at NC State (software.ncsu.edu/approved-ai-solutions/)
- Classification: **Green** (Normal, lowest risk tier)
- Running locally with SSH/SMB is fully compliant — zero HPC resources consumed

---

## Configuration Variables

Replace these placeholders throughout the guide with your actual values:

| Variable | Example | Description |
|----------|---------|-------------|
| `$UNITY_ID` | `frodrig4` | Your NCSU Unity ID |
| `$MAC_USER` | `fvrodriguez` | Your macOS username (`whoami`) |
| `$GROUP_FOLDER` | `rrellan` | The rsstu group folder name |
| `$GROUP_PATH` | `rsstu/users/r/rrellan` | Full SMB share path |
| `$PROJECT_DIR` | `DOE_CAREER/inv4m/assembly` | Project path within the group folder |
| `$SMB_SERVER` | `oitrspprd.hpc.ncsu.edu` | NCSU research storage SMB server |

---

## Component 1: SMB Mount

### The Problem

macOS Finder mounts SMB shares under `/Volumes/` with names that can change between connections (e.g., `/Volumes/DOE_CAREER`, `/Volumes/DOE_CAREER-1`). macOS Tahoe (26) also broke the Finder sidebar → SMB auto-reconnect. `/Volumes/` requires root to create directories and macOS cleans it on reboot.

### The Solution

Mount under the home directory (`~/mnt/$GROUP_FOLDER`) — no root required, fixed path, survives reboots.

### Mount Script: `mount_rrellan.sh`

Deploy to `~/bin/` and make executable. Adapt the variables at the top.

```bash
#!/bin/bash
# Auto-mount NCSU research storage when VPN is active
# Triggered by LaunchAgent on network changes or at login

MOUNT_POINT="/Users/$MAC_USER/mnt/$GROUP_FOLDER"
SMB_SERVER="oitrspprd.hpc.ncsu.edu"
SMB_SHARE="$GROUP_PATH"
USERNAME="$UNITY_ID"

# --- VPN / reachability check ---
if ! nc -z -w 3 "${SMB_SERVER}" 445 2>/dev/null; then
    # Server unreachable (VPN off or network down)
    # Unmount stale mount to avoid Finder hangs
    if mount | grep -q "${MOUNT_POINT}"; then
        umount "${MOUNT_POINT}" 2>/dev/null
        echo "$(date): VPN down, unmounted ${MOUNT_POINT}" >> /tmp/mount_rrellan.log
    fi
    exit 0
fi

# --- Already mounted? ---
if mount | grep -q "${MOUNT_POINT}"; then
    exit 0
fi

# --- Create mount point if needed ---
[ -d "${MOUNT_POINT}" ] || mkdir -p "${MOUNT_POINT}"

# --- Get password from Keychain ---
PASSWORD=$(security find-internet-password -s "${SMB_SERVER}" -a "${USERNAME}" -r "smb " -w 2>/dev/null)

if [ -z "${PASSWORD}" ]; then
    echo "$(date): ERROR - No keychain entry for ${SMB_SERVER}" >> /tmp/mount_rrellan.log
    exit 1
fi

# --- URL-encode password (handles special chars safely) ---
ENCODED_PW=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "${PASSWORD}")

# --- Mount ---
mount_smbfs "//${USERNAME}:${ENCODED_PW}@${SMB_SERVER}/${SMB_SHARE}" "${MOUNT_POINT}"

if [ $? -eq 0 ]; then
    echo "$(date): Mounted at ${MOUNT_POINT}" >> /tmp/mount_rrellan.log
else
    echo "$(date): ERROR - mount_smbfs failed" >> /tmp/mount_rrellan.log
    exit 1
fi
```

### LaunchAgent: Auto-mount on Login and Network Changes

Save as `~/Library/LaunchAgents/com.$UNITY_ID.mount-$GROUP_FOLDER.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$UNITY_ID.mount-$GROUP_FOLDER</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/$MAC_USER/bin/mount_$GROUP_FOLDER.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WatchPaths</key>
    <array>
        <string>/Library/Preferences/SystemConfiguration</string>
    </array>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>/tmp/mount_$GROUP_FOLDER.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mount_$GROUP_FOLDER.log</string>
</dict>
</plist>
```

Load the LaunchAgent:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.$UNITY_ID.mount-$GROUP_FOLDER.plist
```

How it works:
- `RunAtLoad` — runs at login
- `WatchPaths` on `/Library/Preferences/SystemConfiguration` — re-triggers on any network change (VPN connect/disconnect)
- `ThrottleInterval: 5` — prevents firing more than once per 5 seconds
- Script is idempotent: exits immediately if already mounted, unmounts if VPN is down

### Optional: Auto-mount on Terminal Open

Add to `~/.zshrc`:

```bash
~/bin/mount_$GROUP_FOLDER.sh 2>/dev/null &
```

Handles the case where you're already on the network and just opened a terminal (no network change event to trigger the LaunchAgent).

### Verify the Mount

```bash
~/bin/mount_$GROUP_FOLDER.sh
ls ~/mnt/$GROUP_FOLDER/$PROJECT_DIR/
cat /tmp/mount_$GROUP_FOLDER.log
```

### SMB Gotchas

**`.smbdelete*` files**: When macOS fails to delete a file over SMB (lock, timeout), it leaves a `.smbdeleteAAA*` tombstone file. These are stale remnants of failed deletions. To clean them up, delete from the server side via SSH — never fight the SMB client:

```bash
ssh hazel "find /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR -name '.smbdelete*' -ls"
# Review, then:
ssh hazel "find /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR -name '.smbdelete*' -delete"
```

**`.DS_Store` and `._*` files**: macOS Finder creates these on any directory it opens. Harmless but messy. Add to `.gitignore`:

```
.DS_Store
._*
```

---

## Component 2: SSH Configuration

### The Problem

NCSU HPC enforces **Duo 2FA**. The server only accepts `keyboard-interactive` authentication — public key auth (`publickey`) is not offered. `ssh-copy-id` and passwordless SSH do not work. Every new SSH connection requires interactive Duo approval.

### The Solution: ControlMaster + ControlPersist

The user authenticates once interactively in a terminal. The ControlMaster socket keeps the authenticated connection alive. All subsequent `ssh hazel "..."` commands from Claude Code reuse this socket without re-triggering Duo.

### SSH Config

Add to `~/.ssh/config`:

```
Host hazel
    HostName login.hpc.ncsu.edu
    User $UNITY_ID
    IdentityFile ~/.ssh/id_ed25519
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 60m
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Create the sockets directory:

```bash
mkdir -p ~/.ssh/sockets
```

### How ControlMaster Works

```bash
# Step 1: Authenticate interactively (do this in a regular terminal, not Claude Code)
# IMPORTANT: Must use "ssh hazel" — NOT "ssh $UNITY_ID@login.hpc.ncsu.edu"
ssh -Y hazel
# → Complete Duo push/passcode
# → ControlMaster socket created at ~/.ssh/sockets/$UNITY_ID@login.hpc.ncsu.edu-22
# → Can exit or keep terminal open

# Step 2: Claude Code commands now work without Duo prompts
ssh hazel "bjobs"
ssh hazel "bsub < /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR/scripts/my_job.sh"

# Socket expires after 60 min of zero SSH activity → re-authenticate in terminal
```

`ControlPersist 60m` resets the timer on every SSH command. Active Claude Code sessions effectively never time out.

### Verify the Socket

```bash
ssh -O check hazel 2>&1
# → "Master running (pid=XXXXX)" = active
# → "No such file or directory" = expired, re-authenticate with "ssh -Y hazel"
```

### Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `ssh $UNITY_ID@login.hpc.ncsu.edu` instead of `ssh hazel` | Connection works but no ControlMaster socket created | Always use the alias |
| Missing `~/.ssh/sockets/` directory | Socket creation fails silently | `mkdir -p ~/.ssh/sockets` |
| SSH key doesn't exist at the `IdentityFile` path | SSH warnings (harmless — server ignores keys anyway) | Point to an existing key or remove the line |
| ControlPersist too short | Socket expires mid-session | Use `60m` |

---

## Component 3: Claude Code Project Configuration

### `.claude/settings.json`

This file controls permissions and the macOS seatbelt sandbox. Create it in the project root.

```json
{
  "permissions": {
    "allow": [
      "Read(~/mnt/$GROUP_FOLDER/**)",
      "Write(~/mnt/$GROUP_FOLDER/$PROJECT_DIR/**)",
      "Bash(ssh hazel \"bjobs *\")",
      "Bash(ssh hazel \"bpeek *\")",
      "Bash(ssh hazel \"bsub *\")",
      "Bash(ssh hazel \"bhist *\")",
      "Bash(ssh hazel \"bkill *\")",
      "Bash(ssh hazel \"bqueue *\")",
      "Bash(ssh hazel \"source /usr/local/apps/miniconda20240526/etc/profile.d/conda.sh && conda *\")"
    ],
    "deny": []
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "excludedCommands": ["ssh:*"],
    "filesystem": {
      "allowWrite": ["//Users/$MAC_USER/mnt/$GROUP_FOLDER/$PROJECT_DIR/**"]
    },
    "network": {
      "allowedDomains": ["login.hpc.ncsu.edu", "oitrspprd.hpc.ncsu.edu"]
    }
  }
}
```

### How the Sandbox Works

Three layers of defense:

```
Layer 1: Permission rules (settings.json)
  → Which commands are pre-approved vs require prompting
  → Controls Read/Write/Bash tool access

Layer 2: macOS seatbelt sandbox
  → OS-level enforcement of filesystem write restrictions
  → Cannot be bypassed by Claude Code
  → Restricts local Bash commands

Layer 3: UNIX permissions (server-side)
  → Group folder: user can only write to own directories
  → Enforced by the HPC server regardless of client
```

Key settings explained:

| Setting | Value | Effect |
|---------|-------|--------|
| `enabled` | `true` | All Bash commands run inside seatbelt sandbox |
| `autoAllowBashIfSandboxed` | `true` | Sandboxed commands don't need individual approval |
| `excludedCommands` | `["ssh:*"]` | SSH excluded because seatbelt can't sandbox remote execution — the `ssh:*` glob matches any ssh subcommand, falls back to permission rules |
| `allowWrite` | Project folder | OS-level: even if Claude Code tried to write elsewhere, macOS blocks it |
| `allowedDomains` | HPC hostnames | **Required** — empty `[]` blocks ALL DNS resolution from sandboxed commands |

### Why `allowedDomains` Must Not Be Empty

The sandbox's DNS restriction operates at the macOS `mDNSResponder` level via Mach IPC. An empty `allowedDomains: []` blocks all hostname resolution — including for SSH (even though SSH is in `excludedCommands`). The `excludedCommands` exclusion only skips the filesystem/process sandbox, not the DNS policy. You must list every domain Claude Code needs to resolve.

### `.claude/settings.local.json`

Per-user overrides that are NOT committed to version control. Merged on top of `settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(ssh hazel:*)",
      "WebSearch",
      "WebFetch(domain:bjorn.now)"
    ]
  }
}
```

- `Bash(ssh hazel:*)` — auto-approves all `ssh hazel` commands without prompting (broader than the specific patterns in `settings.json`)
- `WebSearch` — allows web search without prompting
- `WebFetch(domain:bjorn.now)` — allows fetching from bjorn.now

### `.claudeignore`

Create in the project root to avoid indexing large files over SMB:

```
# Large output directories
hifiasm/
ragtag/
anchorwave/
raw/
logs/
*.maf
*.sam
*.bam
*.fa
*.fasta
*.gfa
*.fastq.gz
```

Adjust to match your project's large file patterns.

---

## Component 4: The Development Workflow

### The Debugging Cycle

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. WRITE/EDIT locally ──→ 2. RUN on HPC ──→ 3. READ error    │
│      (SMB mount)               (ssh hazel)      (SSH or SMB)    │
│         │                                            │          │
│         └────────────── 4. FIX locally ◄─────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

1. Claude Code writes/edits files through SMB (Read, Edit, Write tools)
2. Claude Code runs the command via `ssh hazel "bash /rsstu/.../script.sh"` or submits a job via `ssh hazel "bsub < /rsstu/.../script.sh"`
3. Read errors via `ssh hazel "cat /rsstu/.../logfile"` or directly via SMB
4. Claude Code edits the file through SMB, then re-runs

The ControlMaster socket (~50ms per SSH round-trip) makes this cycle fast enough for rapid iteration.

### SSH Command Patterns

**Simple one-liners** — for LSF, conda, `ls`, etc.:

```bash
ssh hazel "bjobs 311295"
ssh hazel "bpeek 311295 2>&1 | tail -30"
ssh hazel "ls -lh /rsstu/users/r/$GROUP_FOLDER/"
```

**Complex commands** — write a script file via SMB and run it:

```bash
# Claude Code writes the script via SMB mount (local file I/O)
# → ~/mnt/$GROUP_FOLDER/$PROJECT_DIR/scripts/my_script.sh

# Then executes it on HPC (same file, different path)
ssh hazel "bash /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR/scripts/my_script.sh"
```

This avoids quoting hell. Since SMB and HPC see the same filesystem, Claude Code writes locally and SSH executes remotely.

**Rule of thumb:** If the command needs escaping beyond simple double quotes, make it a script file.

### Path Translation

The same files are visible at two paths:

| Context | Path |
|---------|------|
| macOS (Claude Code) | `~/mnt/$GROUP_FOLDER/$PROJECT_DIR/` |
| HPC (SSH commands, job scripts) | `/rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR/` |

Scripts use HPC absolute paths. Claude Code reads/writes via the local mount. Only SSH commands use HPC paths.

---

## Full Setup Checklist

For a Claude agent setting this up on a new laptop:

### Prerequisites
- [ ] macOS (tested on Sequoia 15, Tahoe 26)
- [ ] Node.js installed (`brew install node`)
- [ ] Cisco AnyConnect VPN configured for NCSU (if off-campus)
- [ ] NCSU Unity ID with HPC access

### One-Time Setup
- [ ] `npm install -g @anthropic-ai/claude-code`
- [ ] `mkdir -p ~/mnt/$GROUP_FOLDER`
- [ ] `mkdir -p ~/bin`
- [ ] `mkdir -p ~/.ssh/sockets`
- [ ] Store SMB credentials in Keychain (Finder → Cmd+K → `smb://$SMB_SERVER/$GROUP_PATH`)
- [ ] Create SSH config entry for `Host hazel`
- [ ] Deploy mount script to `~/bin/mount_$GROUP_FOLDER.sh` and `chmod u+x`
- [ ] Deploy LaunchAgent plist to `~/Library/LaunchAgents/`
- [ ] `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.$UNITY_ID.mount-$GROUP_FOLDER.plist`
- [ ] Optionally add mount script to `~/.zshrc`
- [ ] Verify: `~/bin/mount_$GROUP_FOLDER.sh && ls ~/mnt/$GROUP_FOLDER/`

### Per-Project Setup
- [ ] `cd ~/mnt/$GROUP_FOLDER/$PROJECT_DIR`
- [ ] Create `.claude/settings.json` with permissions and sandbox config
- [ ] Create `.claudeignore` for large files
- [ ] `ssh -Y hazel` → Duo 2FA → verify `ssh -O check hazel`
- [ ] `claude` → start working

### Each Session
- [ ] Ensure VPN is connected (if off-campus)
- [ ] Verify mount: `ls ~/mnt/$GROUP_FOLDER/`
- [ ] Verify SSH socket: `ssh -O check hazel` — if expired, `ssh -Y hazel` and approve Duo
- [ ] `cd ~/mnt/$GROUP_FOLDER/$PROJECT_DIR && claude`

---

## Troubleshooting

### SSH: "Permission denied (keyboard-interactive)"

The ControlMaster socket is expired or was never created. Re-authenticate:

```bash
ssh -Y hazel
# → Approve Duo push
ssh -O check hazel
# → "Master running (pid=XXXXX)"
```

### SSH: "Could not resolve hostname" (error -65563)

The sandbox `allowedDomains` is blocking DNS. Error code `-65563` is macOS `kDNSServiceErr_PolicyDenied`. Add the required domains to `.claude/settings.json`:

```json
"allowedDomains": ["login.hpc.ncsu.edu", "oitrspprd.hpc.ncsu.edu"]
```

### SMB: Mount hangs or Finder freezes

VPN dropped while mount was active. Force unmount:

```bash
umount -f ~/mnt/$GROUP_FOLDER
# Reconnect VPN, then:
~/bin/mount_$GROUP_FOLDER.sh
```

### SMB: `.smbdelete*` files won't go away

Delete from the server side via SSH:

```bash
ssh hazel "find /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR -name '.smbdelete*' -ls"
ssh hazel "find /rsstu/users/r/$GROUP_FOLDER/$PROJECT_DIR -name '.smbdelete*' -delete"
```

### Claude Code: Commands blocked by sandbox

Check `.claude/settings.json` permissions. Commands not matching pre-approved patterns trigger a prompt. SSH commands must match the `Bash(ssh hazel "...")` patterns exactly.

### Finder Sidebar Shortcuts Broken (Tahoe)

macOS Tahoe broke Finder sidebar → SMB auto-reconnect. Workaround:

1. Mount the share
2. In Finder, navigate to `~/mnt/$GROUP_FOLDER`
3. Right-click → Make Alias
4. Drag the alias to the sidebar

The alias survives disconnection and triggers reconnection on click.

---

## Limitations

1. **SMB latency**: File reads/writes add ~10-50ms network round-trip. Globbing large directories is slower. Mitigate with `.claudeignore`.
2. **SSH per command**: Each Bash call opens a new SSH channel (~50ms with ControlMaster, ~200-400ms without).
3. **VPN required**: SMB and SSH require Cisco AnyConnect when off-campus.
4. **Large files**: Don't read multi-GB files (MAF, FASTA, BAM) through Claude Code. Use SSH commands to inspect them on the HPC side.
5. **Duo 2FA**: Manual priming required once per 60 minutes of inactivity. No workaround unless NCSU OIT grants a publickey auth exemption.
6. **No autofs**: The traditional `/etc/auto_master` approach is broken on macOS Tahoe and requires plaintext credentials. The mount script + LaunchAgent approach avoids these issues.
