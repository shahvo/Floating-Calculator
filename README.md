# Floating Calculator

A small native macOS calculator that can stay above other app windows.

The window opens as a compact 236 x 340 utility near the top-right of the
visible screen, so it is easy to reach without covering much of your work.

## Build

```sh
chmod +x build-app.sh
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

The `Float` checkbox is enabled by default. Turn it off to return the window to normal macOS window behavior.
