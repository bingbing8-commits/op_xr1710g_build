# OpenWrt XR1710G GitHub Actions Build

This repository contains a GitHub Actions workflow for building OpenWrt firmware for the XR1710G on a Linux runner.

The default build source is:

- ImmortalWrt tree: `https://github.com/immortalwrt/immortalwrt.git`
- Branch: `master` (kernel 6.18 for the Airoha target)
- Merged XR1710G integration branch: `xr1710g-6.18-integration` from `https://github.com/YYH2913/openwrt.git`
- Target: `airoha/an7581`
- Device profile: `econet_xr1710g-ubi` (the integration branch renamed the vendor prefix from `gemtek` to `econet`; old `gemtek_xr1710g*` profile inputs are still accepted and normalized)

Every build clones the ImmortalWrt baseline and then merges the XR1710G integration branch into it with `git merge` inside the runner (`.github/actions/prepare-xr1710g-source`). The only known conflict, the W1700K `DEVICE_PACKAGES` list in `target/linux/airoha/image/an7581.mk`, is resolved deterministically: the integration side wins and ImmortalWrt's `wpad-openssl` preference is re-applied. Any other conflict fails the build so the resolution can be reviewed and updated.

## Usage

1. Push this repository to GitHub.
2. Push to the `main` branch to register the workflows.
3. Open `Actions`.
4. After the toolchain succeeds, the firmware and package workflows run automatically.
5. Run `Build OpenWrt XR1710G` manually later if you want to override inputs.
6. Download the `openwrt-xr1710g-*` artifact after the build completes.

Successful firmware builds publish a GitHub Release containing firmware files and the exported OpenWrt `.config`.

A source watcher workflow checks the ImmortalWrt `master` branch and the YYH2913 `xr1710g-6.18-integration` branch once per hour. When the latest upstream commit pair does not already have matching toolchain, firmware, and package releases, it sends an `openwrt-updated` repository dispatch event to start the normal toolchain -> firmware/packages build chain. Firmware and package release tags embed both the ImmortalWrt and the integration commit, so a rebuild also happens when only the integration branch moves. The watcher can also be run manually with `force_build` to rebuild even when matching releases already exist.

A separate toolchain workflow runs once per week, on repository dispatch, and after build workflow changes. It deletes matching old Actions cache keys at the start of the next toolchain run, then builds the OpenWrt host tools and target toolchain, saves the fresh toolchain into Actions cache, and uploads a profile-specific `openwrt-xr1710g-toolchain-*.tar.zst` archive to a GitHub Release. Automatic firmware and package builds run only after a successful toolchain build and first try to restore the matching toolchain from cache, then from the matching toolchain release. Manual firmware/package runs still attempt a normal OpenWrt build when no prebuilt toolchain is available.

Packages are built by a separate matrix workflow. It uses the final OpenWrt `.config` and `tmp/.packageinfo` metadata to split only source packages selected for the Airoha target across shards, so unrelated platform packages are not treated as XR1710G failures. Every shard builds the target kernel prerequisites before compiling its assigned sources.

Firmware, toolchain, and package shard releases all include the OpenWrt `.config` used for that build.

The expected system firmware artifact is the `*-sysupgrade.itb` file. For XR1710G HTTP Recovery, upload that `*-sysupgrade.itb` file.

## Notes

- Do the OpenWrt source checkout and build on the Ubuntu runner. Avoid cloning the full OpenWrt tree on macOS case-insensitive filesystems.
- The main build tree defaults to ImmortalWrt `master`. XR1710G device support (profile, DTS, base-files, kernel 6.18 backports, mt76/hostapd Wi-Fi 7 fixes, and the in-tree `luci-app-mlo`, `luci-app-airoha-npu`, `luci-app-w1700k-fancontrol`, `luci-app-airoha-flowsense`, and `luci-app-netspeedtest` packages) comes from merging the YYH2913 `xr1710g-6.18-integration` branch; the old file-import from `hurrian/openwrt-w1700k` is no longer used.
- Both branches are fetched with `--shallow-since` (90 days) so the merge base is available; the merge step automatically deepens to a full fetch when the branches have diverged for longer than that window.
- Passing `integration_ref: none` to a manual run builds the plain ImmortalWrt baseline without the merge (no XR1710G profile in that case).
- The packages workflow enables OpenWrt buildbot-style package output with `CONFIG_ALL`, `CONFIG_ALL_KMODS`, and `CONFIG_ALL_NONSHARED`.
- Package shard errors are not ignored. Each shard uploads a uniquely named source list, package-file list, failure report, config, and checksum file before failing. A package Release is published only when every selected source package compiles successfully and every shard report passes validation.
- OpenClash is added from <https://github.com/vernesong/OpenClash> and selected into the firmware as `luci-app-openclash`.
- The default config requires `luci-app-openclash`, `luci-app-mlo`, `luci-app-airoha-npu`, `luci-app-w1700k-fancontrol`, `sing-box`, `luci-proto-wireguard`, and `uboot-envtools`.
- MLO, Airoha NPU, and W1700K fan control LuCI apps ship inside the integration branch; the workflows only verify they are present instead of cloning them.
- The hostapd existing-interface fix now arrives with the integration merge (`602-nl80211-short-circuit-use-existing-iface.patch`). The guarded backport step from <https://github.com/YYH2913/openwrt> stays as a fallback and is skipped when the fix is already in the tree.
- Firmware release titles use `路由器固件 <build time>`. Toolchain release titles use `toolchain <build time>`.
- After uploading Release assets, workflows clean local release staging directories. Toolchain cache files are retained until the next toolchain workflow run begins.
- `actions/cache` cache misses and Node runtime deprecation messages are runner warnings, not build failures.
- Download caches use an explicit versioned namespace. Small failed downloads are removed only from the top level of `dl`, so valid files under `dl/go-mod-cache` are preserved.
- OpenWrt dependency warnings from package Makefiles are expected when all packages are scanned. The actual failure signal is a later `ERROR` or failed workflow step.
- The workflow adds a first-boot wireless defaults script that sets a valid country code, defaulting to `CN`. It runs after the integration branch's own `17-xr1710g-wifi-defaults` script (which presets US/EHT modes), so the country override wins.
- The 5 GHz radio is optionally pinned to channel `36` on first boot to avoid DFS startup delays and client discovery issues.
- U-Boot chainloader images are separate from this system firmware workflow. The `econet_xr1710g-ubi` profile ships without a chainloader artifact; the source preparation step fails if one ever reappears, because it needs a separately built U-Boot binary. Do not flash raw U-Boot artifacts as XR1710G system firmware.
- The XR1710G profile declares `DEVICE_COMPAT_VERSION 2.0`: the BMT/BBT flash layout changed relative to older XR1710G images. Coming from an old layout requires the updated chainloader/U-Boot plus a recovery/initramfs reinstall with a full UBI rebuild; a config-preserving sysupgrade across that boundary is unsafe.

## References

- ImmortalWrt source: <https://github.com/immortalwrt/immortalwrt/tree/master>
- YYH2913 XR1710G 6.18 integration branch: <https://github.com/YYH2913/openwrt/tree/xr1710g-6.18-integration>
- Gemtek XR1710G OpenWrt PR overlay: <https://github.com/openwrt/openwrt/pull/22397>
- W1700K UBI build workflow reference: <https://github.com/OpenWRT-fanboy/w1700k-ubi-build>
- XR1710G U-Boot and HTTP Recovery notes: <https://github.com/YYH2913/http-uboot-xr1710g>
- YYH2913 OpenWrt XR1710G reference branch: <https://github.com/YYH2913/openwrt/tree/xr1710g>
- OpenWrt XR1710G PR: <https://github.com/openwrt/openwrt/pull/22397>
