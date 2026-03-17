# CLAUDE.md

## Project Overview

Custom fork of [Clop](https://github.com/FuzzyIdeas/Clop) (GPLv3) for **Ziben Studio**. macOS clipboard/file optimizer with auto-resize, WebP conversion, and H.265 video encoding.

**Repo**: `ZibenStudio/Clop` (public)
**Bundle ID**: `com.ziben.Clop`

## Development Commands

```bash
# Build Release
cd ~/Evolution/Clop
xcodebuild -project Clop.xcodeproj -scheme Clop -configuration Release -destination 'platform=macOS' build

# Clean build (needed when Info.plist changes)
xcodebuild -project Clop.xcodeproj -scheme Clop -configuration Release -destination 'platform=macOS' clean build

# Install locally
pkill -x Clop; sleep 1
cp -Rf ~/Library/Developer/Xcode/DerivedData/Clop-*/Build/Products/Release/Clop.app/ /Applications/Clop.app/
plutil -replace SUFeedURL -string "https://cdn.jsdelivr.net/gh/ZibenStudio/Clop@main/appcast.xml" /Applications/Clop.app/Contents/Info.plist
open /Applications/Clop.app

# Change presets via CLI
defaults write com.ziben.Clop activeImagePreset -string "web"     # chat, web, compact, quality
defaults write com.ziben.Clop activeVideoPreset -string "screencast"  # web, screencast, compact, quality
```

## Project Structure

```
Clop/
├── Images.swift          # Image optimization pipeline (Ziben: presets, WebP, resize)
├── Video.swift           # Video optimization pipeline (Ziben: presets, HEVC, resize)
├── Settings.swift        # All settings + preset definitions (ImagePreset, VideoPreset)
├── ContentView.swift     # Menu bar UI (Ziben: preset selector)
├── OptimisationUtils.swift # Optimization orchestration (Ziben: Pro limits removed)
├── ClopApp.swift         # App entry point, clipboard watcher
├── required.swift        # License verification stubs
├── Info.plist            # Sparkle feed URL, EdDSA public key
├── InternetAccessPolicy.plist  # Network domains whitelist
└── Clop.entitlements     # App entitlements (no iCloud)
```

## Ziben Customizations

All custom code is marked with `// Ziben custom` or `// (Ziben custom)` comments.

### Image Presets (Settings.swift → IMAGE_PRESETS)
| Preset | Max Resolution | WebP Quality | Usage |
|--------|---------------|-------------|-------|
| chat (default) | 1920x1080 | 60 | Discord, Teams, Claude |
| web | 2560x1440 | 80 | Sites, Odoo |
| compact | 1280x720 | 50 | Email |
| quality | No resize | 90 | Full detail |

### Video Presets (Settings.swift → VIDEO_PRESETS)
| Preset | Max Resolution | FPS | Codec | Usage |
|--------|---------------|-----|-------|-------|
| web (default) | 2560x1440 | 30 | H.265 | Presentations |
| screencast | 1920x1080 | 30 | H.265 | Demos |
| compact | 1280x720 | 30 | H.265 | Messaging |
| quality | No resize | 60 | H.264 | Original |

### Key Changes from Upstream
- **Pro limits removed** — `proGuard()` in OptimisationUtils.swift bypassed
- **Auto WebP conversion** — clipboard + watched folders (Desktop/Downloads)
- **Auto resize** — images and videos resized per active preset
- **H.265 encoding** — `hevc_videotoolbox` hardware on Apple Silicon
- **Preset UI** — menu bar selector for switching presets
- **Sparkle auto-update** — appcast in repo, served via jsdelivr CDN
- **iCloud removed** — Personal Team signing, no KVS entitlement

## Release Process

See `RELEASE.md` for full deployment instructions.

**Critical**: Always bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` before building a release.

**GitHub account**: Use `MathisFr63` (`gh auth switch --user MathisFr63`)

## Known Issues

- `SUFeedURL` gets cached in UserDefaults — after changing it in Info.plist, run:
  `defaults delete com.ziben.Clop SUFeedURL`
- `cp -R` may not overwrite Info.plist in /Applications — use `cp -Rf source/ dest/` (trailing slash)
- jsdelivr caches appcast.xml — purge after update:
  `curl https://purge.jsdelivr.net/gh/ZibenStudio/Clop@main/appcast.xml`
