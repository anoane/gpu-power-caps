#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Removes the boot service and the script. Usage: sudo ./uninstall.sh
# The current power limits and persistence mode stay as they are until the next driver load or reboot.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
systemctl disable --now gpu-power-caps.service 2>/dev/null || true
rm -f /etc/systemd/system/gpu-power-caps.service /usr/local/sbin/gpu-power-caps
systemctl daemon-reload
echo "gpu-power-caps removed; limits now: "
nvidia-smi --query-gpu=index,pci.bus_id,name,power.limit --format=csv,noheader
