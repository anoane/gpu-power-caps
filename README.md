<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# gpu-power-caps

GPU power caps. Copyright (C) 2026 Fabiano Anemone <fabiano.anemone@gmail.com>.
Licensed AGPL-3.0-or-later with an attribution term: see [LICENSE.md](LICENSE.md).

A boot-time oneshot that sets NVIDIA GPU power limits by card **model**, never by index, and fails
closed when the machine does not hold exactly the cards it expects. It was written for a workstation
with four NVIDIA CMP 170HX and one RTX PRO 6000. With the shipped tables it applies 150/150/400/150/150 W
(nvidia-smi order: CMP, CMP, PRO, CMP, CMP), whatever the PCI order of the cards.

## What it does

1. It waits up to 60 s for `nvidia-smi` to list the GPUs, then reads `pci.bus_id,pci.device_id` for every card.
2. It looks each card's PCI device id up in `CAP`: the device id followed by the NVIDIA vendor id `10de`,
   lower case, as `nvidia-smi` prints it.
3. It checks the cap against the card's `power.min_limit`..`power.max_limit`.
4. On each card, addressed by its PCI bus id (`nvidia-smi -i <bus id>`), it sets persistence mode
   (`-pm 1`) and the limit (`-pl <watts>`), then reads the limit back.
5. It compares the number of cards of each model with `EXPECT`.

Every failure is reported, and the exit status is non-zero:

- a card model with no `CAP` entry;
- a cap outside the card's range;
- a failed set or read-back;
- a model found more or fewer times than `EXPECT` lists.

Any unit can then add `Requires=gpu-power-caps.service` and never start on an uncapped or unexpected set
of cards. Persistence mode keeps the cap after the last GPU client exits.

`DRY_RUN=1 gpu-power-caps` prints the commands it would run and performs every check, as any user.
`gpu-power-caps --version` prints the author notice.

## Configuration

The two tables at the top of `gpu-power-caps`:

```bash
declare -A CAP=(            # device id -> "watts label"
  [0x2bb110de]="400 RTX-PRO-6000"
  [0x20c210de]="150 CMP-170HX"
  [0x268410de]="250 RTX-4090"
)
declare -A EXPECT=(         # device id -> number of such cards in this machine
  [0x2bb110de]=1
  [0x20c210de]=4
)
```

Find the device ids with `nvidia-smi --query-gpu=index,pci.bus_id,name,pci.device_id,power.min_limit,power.max_limit --format=csv`.
Every model in the machine needs a `CAP` entry and an `EXPECT` count. A `CAP` entry without a card is
allowed: the RTX 4090 entry above is an example.

## Install as a boot service

```sh
sudo ./install.sh
```

The installer runs a dry run first and stops if any check fails. Then it does the following:

- installs `/usr/local/sbin/gpu-power-caps` and `/etc/systemd/system/gpu-power-caps.service`;
- runs `systemctl enable --now`;
- restarts the unit once, so the caps apply now even if it was already active;
- prints the resulting limits.

The unit (`systemd/gpu-power-caps.service`) is `Type=oneshot` with `RemainAfterExit=yes`. It runs after
`nvidia-persistenced.service`, and after `cmpunlocker-passthrough.service` where that exists, because
the latter changes CMP persistence. `WantedBy=multi-user.target` makes it run at every boot.

Check or reapply:

```sh
systemctl status gpu-power-caps.service
sudo systemctl restart gpu-power-caps.service
nvidia-smi --query-gpu=index,pci.bus_id,name,power.limit --format=csv,noheader
```

## Uninstall

```sh
sudo ./uninstall.sh
```

This disables the unit and removes the unit and the script. The limits currently set stay in effect
until the next driver load or reboot.
