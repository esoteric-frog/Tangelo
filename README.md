<p align="center">
  <img src="./assets/readme/hero.gif" width="100%" alt="Tangelo: drag a photo.heic file, hold Control, and a wheel of formats opens at the pointer; the WebP slice lights orange.">
</p>

<p align="center">
  <a href="https://github.com/esoteric-frog/Tangelo/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/esoteric-frog/Tangelo/ci.yml?branch=main&style=flat-square&label=tests&color=F26A21" alt="Tests"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B%20·%20Apple%20silicon-2B1A12?style=flat-square&logo=apple&logoColor=white" alt="macOS 14 or later on Apple silicon">
  <img src="https://img.shields.io/badge/Swift-6-F26A21?style=flat-square&logo=swift&logoColor=white" alt="Swift 6">
  <a href="https://github.com/esoteric-frog/Tangelo/releases/latest"><img src="https://img.shields.io/github/v/release/esoteric-frog/Tangelo?style=flat-square&color=2B1A12&label=download" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/esoteric-frog/Tangelo?style=flat-square&color=9A7B63" alt="License"></a>
</p>

<p align="center">
  <b>Tangelo is a tiny Mac menu-bar app that converts files where you drag them.</b><br>
  No window to open, no upload, no settings. The new file lands next to the old one.
</p>

<p align="center">
  <a href="https://esoteric-frog.github.io/Tangelo/"><img src="https://img.shields.io/badge/▶%20Try%20it%20in%20your%20browser-F26A21?style=for-the-badge" alt="Try it in your browser"></a>
</p>

---

## Try it first

No Mac needed. The [**try-it page**](https://esoteric-frog.github.io/Tangelo/) has a sample photo. Drag it, hold <kbd>⌃</kbd>, and drop it on a slice. You get a real converted file to download. You can use your own image too, and it never leaves your browser. On a phone, tap the photo, then tap a key button.

## Three wheels, one per key

Start dragging any file, from Finder or any app. Hold one key and a wheel opens right under the pointer. Let go of the file on a slice.

<p align="center">
  <img src="./assets/readme/wheels.svg" width="100%" alt="Control opens Convert (JPG, PNG, TIFF, AVIF, WebP). Command opens Tools (Compress, Resize 50%, Smaller PDF). Option opens Actions (AirDrop, Copy, Copy Paths, Open in Terminal, Show in Finder).">
</p>

| Hold | Wheel | What is on it |
| :---: | --- | --- |
| <kbd>⌃</kbd> | **Convert** | JPG · PNG · TIFF · HEIC · AVIF · WebP, and Smaller PDF |
| <kbd>⌘</kbd> | **Tools** | Compress · Resize 50% · Smaller PDF |
| <kbd>⌥</kbd> | **Actions** | AirDrop · Copy Files · Copy Paths · Open in Terminal · Show in Finder |

The wheel only shows choices that work for **every** file you are dragging. Drop in the middle, or anywhere off the wheel, and nothing happens.

Prefer clicking? Drop files on the menu-bar icon, or click it and choose **Choose Files…**.

## What it reads

| In | Out |
| --- | --- |
| HEIC, JPEG, PNG, TIFF, WebP, AVIF, GIF, BMP | JPG, PNG, TIFF, HEIC, AVIF, WebP |
| PDF | a smaller PDF (kept only if it really is smaller) |

## Small promises

- **Never overwrites.** `photo.heic` becomes `photo.jpg`. If that name is taken, you get `photo 2.jpg`.
- **No half files.** Tangelo writes to a temp file, then moves it into place. A failed job leaves nothing behind.
- **Nothing leaves your Mac.** Images use Apple's own ImageIO and PDFKit. WebP uses Google's `cwebp`, which ships inside the app.
- **No permissions to grant.** Tangelo sees drags by watching the mouse and the drag pasteboard, so it does not need Accessibility access.

## Install

You need macOS 14 or later on Apple silicon, and the Swift 6 toolchain (Xcode or just the Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/esoteric-frog/Tangelo.git
cd Tangelo
scripts/install.sh      # builds, copies to /Applications, starts it
```

Tangelo adds itself to Login Items the first time it runs from `/Applications`.

<details>
<summary><b>Using the release download instead</b></summary>

The app on the [Releases](https://github.com/esoteric-frog/Tangelo/releases) page is ad-hoc signed, not notarized. macOS will block it the first time. After you move it to `/Applications`, run:

```bash
xattr -dr com.apple.quarantine /Applications/Tangelo.app
```
</details>

## Build and test

```bash
scripts/test.sh         # swift test (works without full Xcode)
scripts/make-app.sh     # builds build/Tangelo.app, ad-hoc signed
```

`scripts/fetch-tools.sh` downloads `cwebp` from Google and checks its SHA-256 before use.

<details>
<summary><b>How it fits together</b></summary>

```mermaid
flowchart LR
  D[Drag + held key] --> W[Wheel]
  M[Drop on menu-bar icon] --> P[Panel]
  W --> R[Registry]
  P --> R
  R --> C1[ImageConverter<br/>ImageIO + cwebp]
  R --> C2[PDFShrinkConverter<br/>PDFKit]
  R --> C3[ImageToolConverter<br/>compress / resize]
  C1 & C2 & C3 --> Q[JobQueue<br/>2 at a time]
  Q --> N[OutputNamer<br/>temp file, then move]
```

- `Sources/TangeloCore` holds the logic and has no UI, so all of it is under test.
- `Sources/Tangelo` is the menu-bar app: the drag watcher, the wheel and the panel.
- A new format is one new `Converter`. The wheel and panel do not change.
</details>

## Coming next

- [ ] Video and audio (bundled `ffmpeg`)
- [ ] Documents: Word, Pages, EPUB, PowerPoint
- [ ] Strip photo metadata, read QR codes
- [ ] A floating shelf that holds files for later

## License

[MIT](LICENSE). `cwebp` is BSD 3-Clause; its notice ships in `Tangelo.app/Contents/Resources/licenses/`.

<p align="center"><img src="./assets/readme/footer.svg" width="160" alt="A small orange wheel of five slices"></p>
