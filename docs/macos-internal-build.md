# GCompris macOS arm64 internal build

This guide builds an unsigned arm64 `.dmg` for personal/internal use.

## 1) Install prerequisites

1. Xcode Command Line Tools:
   `xcode-select --install`
2. CMake + Ninja (recommended):
   `brew install cmake ninja`
3. Qt 6.5+ for macOS arm64 from the Qt online installer:
   install a kit like `~/Qt/6.10.0/macos`.

Notes:
- `git` is required because the source tarball does not include `external/qml-box2d`.
- Translation build is disabled by default to avoid requiring gettext for internal builds.

## 2) Build DMG

From the project root:

```bash
chmod +x tools/macos_build_dmg.sh
tools/macos_build_dmg.sh
```

If auto-detection of Qt fails:

```bash
tools/macos_build_dmg.sh --qt-root "$HOME/Qt/6.10.0/macos"
```

Important:
- This packaging script is designed for Qt online installer layouts.
- Homebrew Qt uses split/symlinked frameworks and is unreliable with `macdeployqt` for portable app packaging.

Output DMG:
- `dist/gcompris-qt-26.0-macos-arm64-internal.dmg`

## 3) Install and run

1. Open the DMG.
2. Drag `gcompris-qt.app` to `/Applications`.
3. First launch may be blocked because it is unsigned.
4. If blocked, right-click app -> `Open`, then confirm.

## Optional flags

- Build translations too:
  `tools/macos_build_dmg.sh --with-translations`
- Build with teacher server:
  `tools/macos_build_dmg.sh --with-server`

## Troubleshooting

- `cmake: command not found`
  Install CMake (`brew install cmake`).

- `Qt CMake directory not found`
  Pass `--qt-root` to the script and point to the Qt kit root ending in `/macos`.

- Script says Homebrew Qt is unsupported
  Install Qt using the Qt online installer and pass that path via `--qt-root`.

- qml-box2d download fails
  Check internet access, then rerun the script.

- DMG build succeeds but app does not launch
  Start from Terminal to capture logs:
  `/Applications/gcompris-qt.app/Contents/MacOS/gcompris-qt`
