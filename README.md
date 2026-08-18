# PIXL Wi-Fi Voucher — iOS

SwiftUI port of the [PIXL.Voucher](https://github.com/) Windows Forms cafe till app. Creates MikroTik
hotspot vouchers via the RouterOS REST API and prints receipts to a network ESC/POS printer.

## Build (macOS + Xcode required)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it:
   ```
   brew install xcodegen
   ```
2. Generate the Xcode project:
   ```
   cd pixl-voucher-ios
   xcodegen generate
   ```
3. Open `PixlVoucher.xcodeproj` in Xcode.
4. Select the `PixlVoucher` target → **Signing & Capabilities** → set your Team (a free Apple ID works
   for on-device debug builds).
5. Plug in an iPhone (the simulator generally can't reach devices on your LAN — router and printer both
   need real Wi-Fi) and build & run.

## Before first use

- **Router**: needs RouterOS 7.1+ with the REST API service enabled. On the router:
  ```
  /ip service print
  /ip service enable www-ssl
  ```
  Note the port (default 443) if you changed it.
- **Printer**: needs a network interface (Wi-Fi or Ethernet) reachable from the same LAN, listening for
  raw ESC/POS on a TCP port (commonly 9100).
- **In the app**: first launch opens Settings automatically. Enter the MikroTik host (defaults to
  `192.168.88.1`), the API password for the `pixl-voucher` router user, and the printer host/port. Use
  **Test Connection** on both before saving.

## What changed vs. the Windows app

- MikroTik binary API (`tik4net`) → RouterOS REST API over HTTPS (simpler/safer to implement on iOS).
- USB POS-58 printer → network ESC/POS over raw TCP.
- MikroTik host and printer host/port are now editable in Settings instead of hardcoded, since a phone
  isn't tied to one fixed LAN the way the till PC is.
- Credential storage: Keychain instead of Windows DPAPI.

Voucher durations, MikroTik hotspot profile (`PIXL-Guest`), voucher code format, and the overall
create-then-print flow are unchanged.

## Known gaps to fill in

- **App icon**: `AppIcon.appiconset` has no image assigned yet (needs a square 1024×1024 opaque PNG — the
  existing `PIXL_logo.png` is a horizontal lockup, not icon-shaped). Builds fine for on-device testing
  without one; required before an App Store submission.
- **Logo asset**: `PixlLogo.imageset/PIXL_logo.png` was copied straight from the Windows app's Assets
  folder and is ~7MB — works, but worth compressing/resizing before shipping.

## If Xcode reports build errors

This project was authored without access to Xcode/macOS, so it hasn't been compile-verified. Send back
any errors and they'll get fixed.
