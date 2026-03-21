# Radio

macOS menu bar radio player built with SwiftUI.

Latest release:

[Download the latest DMG](https://github.com/VitalTatun/Radio/releases/latest)

## Build DMG

Create a release build and package it into a DMG with one command:

```bash
bash /Users/vital/Development/Radio/scripts/make_dmg.sh
```

Versioned DMG file:

```bash
bash /Users/vital/Development/Radio/scripts/make_dmg.sh --version v1.2.0
```

Optional custom background image:

```bash
bash /Users/vital/Development/Radio/scripts/make_dmg.sh --background /path/to/background.png
```

Output:

```text
/Users/vital/Development/Radio/dist/Radio.dmg
```

For headless environments such as GitHub Actions:

```bash
bash /Users/vital/Development/Radio/scripts/make_dmg.sh --skip-window-customization
```

## Requirements

- macOS with Xcode command line tools installed
- Finder automation allowed for Terminal if macOS asks during DMG creation

## Installation For Users

1. Download `Radio.dmg`.
2. Open the DMG.
3. Drag `Radio.app` into `Applications`.
4. On first launch, macOS may block the app because it is not signed with a paid Apple Developer certificate.
5. If that happens, use `Right Click > Open` or go to `System Settings > Privacy & Security > Open Anyway`.

## Notes

- The project does not require a paid Apple Developer account to build locally.
- Without notarization, Gatekeeper warnings for other users are expected.
- GitHub Actions workflow is available in `.github/workflows/build-dmg.yml`.
- Published GitHub releases attach a versioned DMG file automatically.

## Self-Hosted Release Builds

The release workflow is configured for a self-hosted macOS runner so GitHub Actions can build with your local Xcode, SDK, and signing setup.

To enable it:

1. Open the GitHub repository.
2. Go to `Settings > Actions > Runners`.
3. Click `New self-hosted runner`.
4. Choose `macOS`.
5. Run the provided setup commands on your Mac inside a dedicated folder.
6. Keep the runner online when publishing a GitHub release.

After that, publishing a release will build and attach the DMG from your own Mac instead of GitHub's hosted runner.
