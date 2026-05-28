# Clop v3 Rebase Notes (Ziben fork)

Notes from porting the Ziben customizations from our 2.11.6 base onto upstream Clop **v3** (`upstream/v3` @ `b7ead15` "PDF parallel optimisation", dated 2026-05-10).

Branch: `rebase/v3`. Result: builds, installs, runs as **v3.1.0** under bundle `com.ziben.Clop`.

## TL;DR

Upstream `v3` is an **unreleased dev branch that does not build outside the author's machine** as-is. It pins a private local package, references a gitignored private file, and depends on private/unpushed framework changes. Each blocker below had to be worked around. The Ziben Pro-unlock + rebrand were then reapplied on top.

The stable fallback remains `main` (2.11.6 + Ziben, fully unlocked, already released).

## Upstream remotes

```
origin    https://github.com/ZibenStudio/Clop.git   (our fork)
upstream  https://github.com/FuzzyIdeas/Clop.git     (added during this work)
```

- `upstream/main` tip = `dd63c58` "2.11.6" (2026-02-19), frozen. We are 0 behind it.
- `upstream/v3` tip = `b7ead15` (2026-05-10), the active 3.0 dev line. 37 commits ahead of the 2.11.6 merge base.
- v3 is a ~7200-line pipeline rewrite: `Pipeline`/`PipelineStep`/`PipelineExecution`, `ImagePipeline`/`VideoPipeline`/`PDFPipeline`/`AudioPipeline`, `Audio.swift`, `CropSize`, `VideoEncoder`, `FileNameTemplate`, `IgnoredAppsPicker`, `WarpDropManager`, `PresetZones`.

## Blockers hit (in order) and fixes

### 1. Git LFS object 404 — `Clop/bin.tar.lrz`
- v3 points to LFS oid `88f2123…` (81.5 MB) which returns **404** on the LFS server.
- Checkout impossible without `GIT_LFS_SKIP_SMUDGE=1`.
- `bin.tar.lrz` = LRZIP archive of the bundled CLI binaries (gifsicle, pngquant, ffmpeg, etc.), decompressed at runtime by the binary manager (`BM.decompressingBinaries`).
- **Fix:** reused our 2.11.6 base's LFS object (`2cf260a…`, 79.7 MB, present locally in `.git/lfs/objects`) — copied it into `Clop/bin.tar.lrz`.
- ✅ **Verified the archive covers v3's needs**: it bundles `ffmpeg 7.0` built with `--enable-libaom --enable-libsvtav1 --enable-libvpx --enable-libx265 --enable-libmp3lame --enable-libopus` (so AV1, HEVC, WebM, audio MP3/FLAC/AAC/Opus all work), plus `cwebp`, `gifsicle`, `gifski`, `gs` (Ghostscript), `jpegoptim`, `pngquant`, `heif-enc` (AVIF/HEIC), `exiftool`, `vipsthumbnail`, `toGainMapHDR`. v3's new audio/AV1/WebM features run on this archive.
- The earlier "audio/AV1 may fail" caveat was pessimistic and incorrect — the 2.11.6 binary set is already feature-complete for v3.

### 2. Private local SwiftPM package — `warpdrop`
- v3 references `XCLocalSwiftPackageReference "../../../Github/alin23/warpdrop/swift"` → resolves to `/Users/Github/alin23/warpdrop/swift`, which exists only on the upstream author's machine. No public repo (`github.com/alin23/warpdrop` → 404).
- WarpDrop = file-sharing feature (drop.lowtechguys.com, AirDrop-like). Only framework symbol used is `WarpDropClient.send(...)`.
- **Fix:** stubbed `Clop/WarpDropManager.swift` — removed `import WarpDrop`, replaced the two `WarpDropClient` functions with no-ops (kept `WDM`, `WarpDropSession`, `Ref` so all call sites compile). Removed the package's 6 entries from `project.pbxproj` (build file, frameworks phase, product dep, local package ref, product dependency block).
- ⚠️ WarpDrop sharing is **disabled** in this build.

### 3. Gitignored private file — `Clop/required.swift`
- v3's `project.pbxproj` lists `required.swift` as a Sources build input, but the file is **`.gitignore`d** (line 8) and never committed (it's upstream's private license-verification file).
- **Fix:** wrote our own stub `Clop/required.swift` providing the symbols the code references:
  - `proactive: Bool` → `true` (the global "is Pro" flag — used by the menubar badge)
  - `validReq() -> Bool` → `true`
  - `invalidReq/invalidReq2/invalidReq3(_ products: [Any], _ window: NSWindow?)` → no-op
  - `hasShortcutsDB() -> Bool` → `true`
- Note: to commit this in our fork it must be force-added (`git add -f`) or removed from `.gitignore`.

### 4. `LowtechProSentry` "missing product" — RED HERRING caused by #5
- First seen as `Missing package product 'LowtechProSentry'`. Initially removed it, which then broke `import Sentry`.
- Root cause was the stale Lowtech checkout (#5). The real (May-17) Lowtech **does** define the `LowtechProSentry` product and it links Sentry. So it was **restored** (import + 4 pbxproj entries).

### 5. ROOT CAUSE — Lowtech branch-pin drift
- Clop pins `FuzzyIdeas/Lowtech` by **branch** (`ventura`), not a fixed revision, and v3 commits **no Lowtech revision** in `Package.resolved`.
- Our local SPM checkout was stale at `faa6f0b` (**2026-02-10**), three months older than v3 (May 10). That old Lowtech lacked `Shortcut`, `SHM`, `ShortcutsFetcher`, `.card`, `.dimmed`, `PipelineAction.runShortcut`, and the `LowtechProSentry` product → ~40 compile errors across 10 files.
- The **real `ventura` HEAD is `6913eef` (2026-05-17)** "Gate SWIFTUI_PREVIEW behind DEBUG" — newer than v3, and it has all the needed API + `Shortcuts.swift` + `Styles.swift`.
- **Fix:** bumped the Lowtech pin in `Package.resolved` from `faa6f0b` → `6913eef`, cleared the stale `SourcePackages/checkouts/Lowtech` + `repositories/Lowtech-*` cache, re-resolved.
- ⚠️ Branch pins are fragile (can re-drift). We now pin a concrete revision.

### 6. IgnoreRust modulemap (pre-existing, also affects 2.11.6)
- Xcode 26.5 stopped auto-discovering the modulemap in `IgnoreRust.xcframework/.../Headers/libIgnore/` (subfolder) when `HeadersPath = Headers`.
- **Fix:** copy `module.modulemap` + the two headers up to the `Headers/` root. Lives in DerivedData (ephemeral) — re-apply after any package re-resolve. Durable fix = vendor/fork `swift-ignore` with corrected header layout.

### 7. Sentry module + stale explicit-module cache
- After restoring LowtechProSentry, `import Sentry` resolves transitively through it.
- A `clean build` was needed once to clear a stale Sparkle `.pcm` ("file has been modified since the module file was built").

## Ziben customizations reapplied (on v3 architecture)

### Pro fully removed
- `OptimisationUtils.swift` `proGuard()` — bypassed the `guard proactive || count < limit, validReq()` so it never throws, never populates `skippedBecauseNotPro`, never calls `proLimitsReached`. Kills the 5-file limit for image/video/audio/PDF/URL/drag.
- `ClopApp.swift` dragMonitor — removed `proactive || DM.optimisationCount <= 5` gate (the actual drag-drop blocker).
- `DropZone.swift` — removed the two `if optimisationCount == 5 { += 1 }` counter bumps that fed the paywall toast.
- `required.swift` — `proactive → true`.
- Cosmetic UI: removed `proErrors` paywall section, "Get Clop Pro" / "Manage license" buttons, "License: Free" label (`ContentView.swift`); `proText → "Pro"` (`SettingsView.swift`). Badge + result-view paywall self-hide because `skippedBecauseNotPro` stays empty.

### Rebrand to com.ziben.Clop
- Global rename `com.lowtechguys.Clop` → `com.ziben.Clop` across `Shared.swift`, `ClopApp.swift`, `ClopUtils.swift`, `Xattr.swift`, `ClopCLI/main.swift`, both `.entitlements`, `project.pbxproj` (bundle ids, mach-port names, defaults suite, app-scripts dir).
- `DEVELOPMENT_TEAM` `RDDXV84A73` → `GNKG3H5UYJ`.
- `Clop.entitlements` — stripped iCloud container + KVS keys (personal team can't sign them), added `apple-events`.
- `Info.plist` — `SUFeedURL` → `https://cdn.jsdelivr.net/gh/ZibenStudio/Clop@main/appcast.xml`, `SUPublicEDKey` → our key `j9O9QqUBlJVJ/KOHdcs6qUKC0Gen+pMgxJUBIr+l7Jg=`.
- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` → `3.1.0` (above lowtechguys' 3.0.0 for Sparkle).

### NOT ported (intentional)
- The hardcoded Ziben image/video presets (chat/web/compact/quality). v3 ships a far more capable **Pipeline DSL** (`optimise -> downscale(0.75) -> convert(webp)`, HEVC via `convert(hevc)` → `hevc_videotoolbox`, crop/resize steps, PresetZones). Configure WebP/resize/HEVC presets in-app instead of hardcoding them.

## Build / install commands used

```bash
# After any package re-resolve, re-apply the IgnoreRust header patch:
D=$(find ~/Library/Developer/Xcode/DerivedData -type d -path "*swift-ignore/IgnoreRust.xcframework/macos-arm64_x86_64/Headers" | head -1)
cp "$D/libIgnore/SwiftBridgeCore.h" "$D/SwiftBridgeCore.h"
cp "$D/libIgnore/ignore.h"          "$D/ignore.h"
cp "$D/libIgnore/module.modulemap"  "$D/module.modulemap"

xcodebuild -project Clop.xcodeproj -scheme Clop -configuration Release -destination 'platform=macOS' build

pkill -x Clop; sleep 1
cp -Rf ~/Library/Developer/Xcode/DerivedData/Clop-*/Build/Products/Release/Clop.app/ /Applications/Clop.app/
plutil -replace SUFeedURL -string "https://cdn.jsdelivr.net/gh/ZibenStudio/Clop@main/appcast.xml" /Applications/Clop.app/Contents/Info.plist
defaults delete com.ziben.Clop SUFeedURL 2>/dev/null
open /Applications/Clop.app
```

## Open items before this could ship as a release
1. Decide tracking of `required.swift` (force-add or un-ignore the path).
2. Commit `bin.tar.lrz` as our own LFS object (currently points at the 2.11.6 object, which is fine functionally but lives under our LFS quota).
3. Re-enable or permanently remove WarpDrop (or leave the stub).
4. Vendor/fork `swift-ignore` so the IgnoreRust header patch survives package re-resolution.
5. Lowtech pin is now a concrete revision in `Package.resolved` (`6913eef`); ideally also pinned in the package reference itself.
6. Optionally recreate the old Ziben hardcoded presets as v3 PresetZones / saved pipelines.
