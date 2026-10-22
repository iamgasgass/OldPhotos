# OldPhotos

> A standalone, modern iOS rebuild of the **Photos** app from **The OldOS Project**, keeping the iOS 6 black-glass look while running full screen on current iPhones and iPads with iOS 16 or later.

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-0A84FF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](#architecture)
[![Build](https://img.shields.io/github/actions/workflow/status/iamgasgass/OldPhotos/build.yml?branch=main&label=build)](https://github.com/iamgasgass/OldPhotos/actions)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey)](#license-and-attribution)

## Overview

**OldPhotos** brings back the iOS 6 Photos app:

- the **Albums** and **Places** tabs under the black tab bar;
- the black translucent title bar laid over the content;
- the 4-column Camera Roll with the soft thumbnail glow and video badges;
- the full-screen viewer with the black glass toolbar (Action, Previous, Play, Next, Trash).

It reads the device photo library through PhotoKit, so everything in your library can be browsed, played, shared and deleted.

## Features

Every screen of OldOS `Photos.swift` is included. Controls that OldOS drew but left inert now work.

### Albums

- **Camera Roll (count)** row with the latest photo as its thumbnail, followed by Favorites and your albums (iOS 6 listed them there too).

### Camera Roll grid

- 4 columns with the OldOS spacing and grey inner glow.
- Videos show the camera badge and their duration.
- "N Photos, M Videos" footer.
- Opens scrolled to the newest photo.
- The **action button** enters iOS 6 selection mode: blue check marks, **Share** and **Delete** for several items at once.

### Viewer

- **Normal size:** photos are shown whole (aspect fit). OldOS filled and cropped the screen.
- **Swipe** between photos. **Pinch** or **double tap** to zoom, at full resolution.
- **Tap** to hide or show the bars; the status bar hides with them.
- **"3 of 120"** title. OldOS always showed the index off by one and stuck at 0.
- **Previous / Next** buttons, disabled at the ends.
- **Play**:
  - on a video: plays and pauses it, with the OldOS play overlay;
  - on a photo: starts the iOS 6 slideshow (crossfade every 3 s; tap to stop).
- **Action** opens the iOS 6 black sheet. It offers Email Photo / Video, Message, Copy Photo and Share…. In OldOS the sheet showed "Email / MMS / Send to YouTube" and did nothing.
- **Trash** shows the red "Delete Photo" sheet, then the library deletion with the iOS confirmation. In OldOS it was inert.

### Places

- Map with the red pins dropped with the iOS 6 animation, framed on your photos.
- Photos are grouped by place (about 1 km).
- Tapping a pin opens that place's photos, titled with the place name.

### Library and appearance

- **Live library:** new shots and deletions (also from other apps) appear immediately. The OldOS 50 000-asset cap and its slow start are gone, because PhotoKit fetch results are used directly.
- **Aspect UI** in Settings › OldPhotos: *Sistema*, *Chiaro* or *Scuro*. The tables use OldSafari's Private palette in Scuro. The black chrome is identical in both, as on iOS 6.
- **Full screen** like OldSafari: the title bar extends behind the status bar and Dynamic Island, and the tab bar and toolbar extend behind the home indicator.

## Architecture

```text
OldPhotos/
├── .github/workflows/build.yml       # XcodeGen + unsigned IPA build
├── project.yml                       # XcodeGen project description
├── OldPhotos/
│   ├── OldPhotosApp.swift            # App / scene delegate, status-bar aware hosting controller
│   ├── Models/PhotosModels.swift     # tabs, albums (Camera Roll / albums / places), viewer request
│   ├── Store/                        # PhotosLibrary (PhotoKit), PhotosNavigator, PhotosActions, PhotosSettings
│   ├── Views/                        # root, chrome, albums, grid, places, viewer + UIKit pager
│   ├── Support/                      # OldOSKit (shared with OldSafari), Photos additions, palette
│   ├── Settings.bundle/              # Settings › OldPhotos (Aspect UI)
│   ├── Assets.xcassets/              # Photos Icons (iOS 6 artwork, renamed) + app icon (Any / Dark / Tinted)
│   └── Info.plist
├── EXTRACTION.json
├── README.md
└── LICENSE
```

## Requirements

- macOS with Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- iPhone or iPad running iOS 16.0 or later.

## Build Locally

```bash
git clone https://github.com/iamgasgass/OldPhotos.git
cd OldPhotos
brew install xcodegen
xcodegen generate
open OldPhotos.xcodeproj
```

## Unsigned IPA via GitHub Actions

The workflow in `.github/workflows/build.yml` runs these steps:

1. Generates the project from `project.yml`.
2. Builds with `CODE_SIGNING_ALLOWED=NO`.
3. Verifies the bundle (icon, Settings.bundle, Photos usage string).
4. Uploads `OldPhotos-Unsigned.ipa` and the build log.

## License and Attribution

OldPhotos is a standalone rebuild derived from the Photos app in **The OldOS Project** by [@zzanehip](https://github.com/zzanehip), licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

## Disclaimer

OldPhotos is an independent, unofficial project, not affiliated with Apple Inc. iOS is a trademark of Apple Inc.

---

- Built by [iamgasgass](https://github.com/iamgasgass)
