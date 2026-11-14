#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Installs gpu-power-caps as a boot service and applies the caps now. Usage: sudo ./install.sh
# A dry run first checks every card against CAP/EXPECT; nothing is installed if it fails.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
cd "$(dirname "$0")"
DRY_RUN=1 ./gpu-power-caps
install -m 0755 -o root -g root gpu-power-caps /usr/local/sbin/gpu-power-caps
install -m 0644 -o root -g root systemd/gpu-power-caps.service /etc/systemd/system/gpu-power-caps.service
systemctl daemon-reload
systemctl enable --now gpu-power-caps.service
# A oneshot that is already active is not rerun by "enable --now": restart applies the caps again.
systemctl restart gpu-power-caps.service
systemctl is-active gpu-power-caps.service
nvidia-smi --query-gpu=index,pci.bus_id,name,persistence_mode,power.limit --format=csv,noheader
