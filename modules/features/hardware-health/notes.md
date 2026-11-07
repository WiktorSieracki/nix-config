# feature notes: hardware-health

*Last updated: 2026-11-07*

## Firmware updates are manual on purpose

Only the metadata refresh is automatic. Apply firmware by hand, on AC power,
when nothing important is due: `fwupdmgr refresh && fwupdmgr get-updates`, then
`fwupdmgr update`. A UEFI capsule update reboots the machine.

## smartd quits when it finds no disks

With `DEVICESCAN` and no SMART-capable device (any VM with only virtio disks)
smartd exits instead of idling. The feature test therefore attaches an emulated
NVMe drive (`-device nvme`), which QEMU backs with a SMART health log.
