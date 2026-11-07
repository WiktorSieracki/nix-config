# feature notes: printing

*Last updated: 2026-11-07*

## Scope: driverless only

The feature assumes IPP Everywhere / AirPrint printers and eSCL/WSD scanners
(sane-airscan). An old USB-only printer that needs a vendor driver needs its
package in `services.printing.drivers` (e.g. `gutenprint`, `hplip`), and a USB
scanner needs the account in the `scanner` and `lp` groups.

Adding a permanent queue: `lpadmin -p <name> -E -v ipp://<host>/ipp/print -m everywhere`,
or simply print from the GTK dialog, which lists discovered printers.

## ippeveprinter aborts in avahi-client (2026-11-07)

In the feature-test VM, `ippeveprinter` started with DNS-SD on (the default)
dies with SIGABRT on an assertion in `request_dispatch` (libavahi-client) right
after start, so it never announces itself and `lpstat -e` never lists it. With
`-r off` it runs fine, which is why the feature test builds its queue by URI
(`lpadmin -m everywhere`) instead of discovering it. Discovery of real printers
goes through cupsd/avahi-daemon, not this code path.
