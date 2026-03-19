# Release Process — Clop Ziben

## Prerequisites

- Xcode with Clop project buildable
- `create-dmg` installed (`brew install create-dmg`)
- GitHub CLI (`gh`) authenticated with MathisFr63
- Sparkle signing keys in Keychain (generated once with `generate_keys`)

## Steps

### 1. Bump version

Edit `Clop.xcodeproj/project.pbxproj` — update all `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` to the new version.

### 2. Build Release

```bash
cd ~/Evolution/Clop
xcodebuild -project Clop.xcodeproj -scheme Clop -configuration Release -destination 'platform=macOS' build
```

### 3. Create DMG

```bash
mkdir -p /tmp/clop-release
cp -R ~/Library/Developer/Xcode/DerivedData/Clop-*/Build/Products/Release/Clop.app /tmp/clop-release/Clop.app
create-dmg \
  --volname "Clop Ziben" \
  --window-pos 200 120 --window-size 600 400 \
  --icon-size 100 --icon "Clop.app" 150 185 \
  --app-drop-link 450 185 \
  ~/Desktop/Clop-Ziben-X.Y.Z.dmg /tmp/clop-release/
```

### 4. Sign DMG with Sparkle

```bash
SPARKLE_BIN=~/Library/Developer/Xcode/DerivedData/Clop-*/SourcePackages/artifacts/sparkle/Sparkle/bin
$SPARKLE_BIN/sign_update ~/Desktop/Clop-Ziben-X.Y.Z.dmg
```

Copy the output `sparkle:edSignature="..."` and `length="..."`.

### 5. Update appcast.xml

Edit `/tmp/clop-appcast/appcast.xml` (or clone `ZibenStudio/clop-appcast`):

```xml
<item>
    <title>Clop Ziben vX.Y.Z</title>
    <pubDate>DATE</pubDate>
    <sparkle:version>X.Y.Z</sparkle:version>
    <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <description><![CDATA[<h2>vX.Y.Z</h2><ul><li>Changes...</li></ul>]]></description>
    <enclosure url="https://github.com/ZibenStudio/Clop/releases/download/vX.Y.Z/Clop-Ziben-X.Y.Z.dmg"
               type="application/octet-stream"
               sparkle:edSignature="SIGNATURE_FROM_STEP_4"
               length="LENGTH_FROM_STEP_4"/>
</item>
```

Push to `ZibenStudio/clop-appcast`.

### 6. Create GitHub Release

```bash
cd ~/Evolution/Clop
git add -A && git commit -m "release: vX.Y.Z"
git push
gh release create vX.Y.Z ~/Desktop/Clop-Ziben-X.Y.Z.dmg --title "Clop Ziben vX.Y.Z" --notes "Release notes..."
```

### 7. Install locally

```bash
pkill -x Clop; sleep 1
rm -rf /Applications/Clop.app
cp -R ~/Library/Developer/Xcode/DerivedData/Clop-*/Build/Products/Release/Clop.app /Applications/Clop.app
open /Applications/Clop.app
```

## Important Notes

- Version must be **higher than 2.11.6** (original Clop version) for Sparkle to detect updates
- GitHub account must be **MathisFr63** (`gh auth switch --user MathisFr63`)
- DMG folder must contain only ONE Clop.app (use a fresh `/tmp/` folder each time)
- Sparkle appcast is public at `ZibenStudio/clop-appcast`
- **NEVER use `cp -Rf source/ dest/` (trailing slash)** — it breaks the code signature. Always `rm -rf` then `cp -R` without trailing slash
- **NEVER modify Info.plist with plutil post-install** — SUFeedURL is already set in the source Info.plist. Modifying it breaks the code signature and Sparkle silently refuses updates
