# YYH2913 XR1710G Backport Design

## Goal

Use compatible XR1710G improvements from `YYH2913/openwrt` without replacing the existing ImmortalWrt 24.10 source, the `gemtek_xr1710g-ubi` device profile, or the Linux 6.6 compatibility work already present in this repository. The resulting firmware, toolchain, and package workflows must complete successfully and publish their normal release assets.

## Options Considered

1. Replace ImmortalWrt with the YYH2913 `xr1710g` branch. This would provide all device changes together, but the branch uses Linux 6.12, names the image profile `econet_xr1710g-ubi`, and is substantially behind its upstream main branch.
2. Import all XR1710G and NPU patches from YYH2913. This keeps ImmortalWrt but mixes Linux 6.12-specific networking, DTS, and driver patches into a Linux 6.6 tree, creating a large and difficult-to-test compatibility surface.
3. Selectively backport userspace fixes and retain the existing device overlay. This preserves the known Gemtek image layout while allowing independently testable fixes to be added.

Option 3 is used.

## Changes

Backport the hostapd `use_existing` short-circuit fix against the exact hostap snapshot used by ImmortalWrt 24.10. Install it only when an equivalent patch is not already present. Keep the current Hurrian-based Gemtek DTS, image profile, NPU DTS, and board files.

Version the shared download cache namespace so no workflow restores the previously damaged Go module cache. Restrict failed-download cleanup to regular files directly under `dl`; never recurse into `dl/go-mod-cache`.

## Verification

Validate all workflow YAML, run `git diff --check`, and apply-check the hostapd patch against hostap commit `5ace39b0a4cdbe18ddbc4e18f80ee3876233c20b`. After pushing, require successful toolchain, firmware, and package workflows, then confirm release publication steps completed.
