# Handover: Set Up Claude Code Project at tlaloc/nil_pipeline

## Context

The user has an existing Claude Code + NCSU HPC workflow on their Mac laptop. The infrastructure (SMB mount, SSH ControlMaster, LaunchAgent, Keychain credentials) is already configured and working. See `agent/claude_code_ncsu_hpc_setup.md` for the full setup guide.

A Nextflow-based NIL assembly pipeline was moved from `DOE_CAREER/inv4m/assembly/` to `tlaloc/nil_pipeline/`. The new project needs its own Claude Code project configuration.

## What's Already Done (Do NOT Redo)

- SMB mount: `~/mnt/rrellan` → `/rsstu/users/r/rrellan/`
- SSH config: `Host hazel` alias with ControlMaster + ControlPersist 60m
- LaunchAgent: auto-mount on login and VPN changes
- Keychain: SMB credentials stored
- Claude Code: installed globally

## What Needs to Be Done

### 1. Create `.claude/settings.json`

Path: `~/mnt/rrellan/tlaloc/nil_pipeline/.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Read(~/mnt/rrellan/**)",
      "Write(~/mnt/rrellan/tlaloc/nil_pipeline/**)",
      "Bash(ssh hazel \"bjobs *\")",
      "Bash(ssh hazel \"bpeek *\")",
      "Bash(ssh hazel \"bsub *\")",
      "Bash(ssh hazel \"bhist *\")",
      "Bash(ssh hazel \"bkill *\")",
      "Bash(ssh hazel \"bqueue *\")",
      "Bash(ssh hazel \"source /usr/local/apps/miniconda20240526/etc/profile.d/conda.sh && conda *\")"
    ],
    "deny": [
      "Write(~/mnt/rrellan/sara/DNA_Sequencing_raw/**)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "excludedCommands": ["ssh:*"],
    "filesystem": {
      "allowWrite": ["//Users/fvrodriguez/mnt/rrellan/tlaloc/nil_pipeline/**"],
      "denyWrite": ["//Users/fvrodriguez/mnt/rrellan/sara/DNA_Sequencing_raw/**"]
    },
    "network": {
      "allowedDomains": ["login.hpc.ncsu.edu", "oitrspprd.hpc.ncsu.edu"]
    }
  }
}
```

### 2. Create `.claudeignore`

Path: `~/mnt/rrellan/tlaloc/nil_pipeline/.claudeignore`

Adjust based on actual directory structure, but likely:

```
work/
results/
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

### 3. Fix Broken Paths in Scripts

All scripts moved from `DOE_CAREER/inv4m/assembly/` will have hardcoded paths. Find and replace:

**Old base path:**
```
/rsstu/users/r/rrellan/DOE_CAREER/inv4m/assembly
```

**New base path:**
```
/rsstu/users/r/rrellan/tlaloc/nil_pipeline
```

To find affected files:

```bash
ssh hazel "grep -rl 'DOE_CAREER/inv4m/assembly' /rsstu/users/r/rrellan/tlaloc/nil_pipeline/"
```

Review each match — some references (like paths to reference genomes in `synteny/ref/`) should still point to DOE_CAREER since the references weren't moved.

### 4. Verify

```bash
cd ~/mnt/rrellan/tlaloc/nil_pipeline
claude
# Then inside Claude Code:
# ssh hazel "ls /rsstu/users/r/rrellan/tlaloc/nil_pipeline/"
```

## Key Details

| Item | Value |
|------|-------|
| macOS user | `fvrodriguez` |
| Unity ID | `frodrig4` |
| SMB mount | `~/mnt/rrellan` |
| HPC project path | `/rsstu/users/r/rrellan/tlaloc/nil_pipeline/` |
| Local project path | `~/mnt/rrellan/tlaloc/nil_pipeline/` |
| Reference genomes | `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/{B73,PT}/` (not moved) |
| Conda envs | `/share/maize/frodrig4/conda/env/{assembly,anchorwave,liftoff,r_plotting,nextflow}` |
| Conda init | `source /usr/local/apps/miniconda20240526/etc/profile.d/conda.sh` |

## Samples to Assemble

These still need assembly (FASTQs exist, not yet processed):

| Sample | Barcodes | FASTQ Location |
|--------|----------|----------------|
| TMEX_inv4m | bc2049+bc2050 | `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/` |
| Z031E0047 (BDI/BNI) | bc2053+bc2054 | `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/` |
| Z031E0050 (BDI/BNI) | bc2055+bc2056 | `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/` |

## Design Rules (Carry Over from inv4m Assembly)

- **NO `ragtag correct`** — misinterprets inversions, breaks contigs
- **hifiasm `-l0`** — disable purging for inbred NILs
- **MAPQ>=60** filtering on dotplot SAMs
- **Liftoff with `-copies`** for CNV detection
- **Dual-reference scaffolding** — B73 (background) + PT (Inv4m arrangement)
