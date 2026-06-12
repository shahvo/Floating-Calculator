# Floating Calculator

A small native macOS calculator that can stay above other app windows, making
quick calculations easier while multitasking.

The window opens as a compact 236 x 340 utility near the top-right of the
visible screen, so it is easy to reach without covering much of your work. The
`Float` checkbox is enabled by default. Turn it off to return the window to
normal macOS window behavior.

macOS can restrict overlays above some fullscreen, secure, or system-owned
surfaces, but the app uses native floating-window behavior and joins Spaces for
the broadest practical coverage.

## Build

```sh
chmod +x build-app.sh package-release.sh
./build-app.sh
```

The app bundle is created at:

```text
.build/Floating Calculator.app
```

## Run

```sh
open ".build/Floating Calculator.app"
```

## Package

Create a shareable zip for testers:

```sh
./package-release.sh
```

The packaged app is written to:

```text
dist/FloatingCalculator-1.0-macOS.zip
```
