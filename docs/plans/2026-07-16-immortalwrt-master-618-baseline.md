# Switch the XR1710G build baseline to ImmortalWrt master + YYH2913 6.18 integration

Date: 2026-07-16

## Goal

Replace the `openwrt-24.10` (kernel 6.6) baseline with an ImmortalWrt branch
that can merge <https://github.com/YYH2913/openwrt/tree/xr1710g-6.18-integration>,
resolve the merge conflicts deterministically, and make that merged tree the
build source for all XR1710G workflows.

## Branch analysis (2026-07-16)

`xr1710g-6.18-integration` (tip `2a845ee80c7c`) is based on official OpenWrt
`main` and carries 51 commits of XR1710G/Airoha work: the
`econet_xr1710g-ubi` device profile and DTS, AN7581/AN7583 kernel 6.18
backports, mt76/hostapd Wi-Fi 7 fixes, SOE/EIP93 offload work, and in-tree
`luci-app-mlo`, `luci-app-airoha-npu`, `luci-app-w1700k-fancontrol`,
`luci-app-airoha-flowsense`, and `luci-app-netspeedtest` packages.

Merge-base distance per candidate ImmortalWrt branch:

| ImmortalWrt branch | merge-base date | commits on integration side | verdict |
| --- | --- | --- | --- |
| `master` | 2026-07-12 (3 days old) | 51 | chosen |
| `openwrt-25.12` | 2025-12-10 | 3079 | far behind |
| `openwrt-24.10` | 2024-10-31 | 7388 | not viable |

Both ImmortalWrt `master` and the integration branch already use
`KERNEL_PATCHVER := 6.18` for `target/linux/airoha`.

## Merge test result

`git merge-tree --merge-base=7ff96bf05c50 <imm-master> <integration>` reports
exactly one conflict; six other files touched by both sides auto-merge:

- Conflict: `target/linux/airoha/image/an7581.mk`, the
  `Device/gemtek_w1700k-ubi` `DEVICE_PACKAGES` list. ImmortalWrt replaced
  `wpad-basic-mbedtls` with `wpad-openssl`; the integration branch added
  `ethtool-full` and `kmod-phy-realtek` on the same lines.
- Auto-merged: `package/kernel/linux/modules/netdevices.mk`,
  `package/kernel/linux/modules/netsupport.mk`, `package/kernel/mt76/Makefile`,
  `target/linux/airoha/dts/an7581-nokia-valyrian.dts`,
  `target/linux/airoha/dts/an7581-w1700k-ubi.dts`,
  `target/linux/airoha/dts/an7581.dtsi`.

A plain file overlay instead of a real merge would discard ImmortalWrt's
changes in the six auto-merged files (for example its kmod additions), so the
workflows perform an actual `git merge` at build time.

## Decisions

1. Baseline: ImmortalWrt `master`, merged with
   `YYH2913/openwrt#xr1710g-6.18-integration` on every build via the new
   composite action `.github/actions/prepare-xr1710g-source`.
2. Conflict policy: only the known `an7581.mk` conflict is auto-resolved
   (integration side wins, then ImmortalWrt's `wpad-openssl` preference is
   restored in the W1700K block). A guard verifies no baseline
   `TARGET_DEVICES` entry is lost. Any other conflict fails the build.
3. History depth: both sides are fetched with `--shallow-since` (90 days);
   the action deepens to a full fetch automatically when no common ancestor
   is inside the window.
4. Device profile: `econet_xr1710g-ubi` (the integration branch renamed the
   vendor from Gemtek to Econet). Old `gemtek_xr1710g*` inputs are
   normalized for backwards compatibility.
5. Release tags now embed both commits
   (`xr1710g[-packages]-<ref>-<imm-short>-<integration-short>`), and the
   hourly watcher probes both branches, so a rebuild triggers when either
   side moves. Toolchain tags and caches stay keyed on the ImmortalWrt
   commit only, because the toolchain does not depend on the device deltas.
6. Steps deleted as obsolete on the 6.18 baseline: hurrian file import,
   XR1710G package-list override, chainloader-artifact strip (the new
   profile has none; a verify step fails if one reappears), AFE DTS strip,
   `patches-6.6` skbuff/PWM compatibility patches, and the pwm-an7581 kmod
   rename (upstream already ships `kmod-pwm-airoha`).
7. Steps kept: guarded hostapd existing-interface backport (the integration
   branch already carries the fix as patch 602; the step then no-ops),
   libffi fficonfig fix (self-guarding), OpenClash clone, CN-default
   first-boot wireless script, and the SND_SOC_AN7581 kernel-config seed
   (now inside the action's verify step).
8. `uboot-envtools` moved from a DEVICE_PACKAGES edit to
   `CONFIG_PACKAGE_uboot-envtools=y` plus the required-package assertion,
   because the new profile does not list it.
