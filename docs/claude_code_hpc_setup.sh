#!/bin/bash
set -euo pipefail

# Write clean Claude Code settings for VCL HPC node (direct LSF access)
#
# Usage:
#   cd /rsstu/users/r/rrellan/tlaloc/nilhifi
#   bash docs/claude_code_hpc_setup.sh
#   # Then restart Claude Code

SETTINGS="/rsstu/users/r/rrellan/tlaloc/nilhifi/.claude/settings.json"

if [ -f "${SETTINGS}" ]; then
    cp "${SETTINGS}" "${SETTINGS}.bak"
    echo "Backed up existing settings to ${SETTINGS}.bak"
fi

cat > "${SETTINGS}" << 'EOF'
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": [
      "bjobs:*",
      "bpeek:*",
      "bsub:*",
      "bhist:*",
      "bkill:*",
      "bqueues:*",
      "conda:*"
    ],
    "network": {
      "allowedDomains": [
        "servlsf",
        "10.1.16.42",
        "github.com"
      ]
    }
  }
}
EOF

echo "Wrote clean VCL settings to ${SETTINGS}"
