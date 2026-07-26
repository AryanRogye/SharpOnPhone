<div align="center">

# SharpOnPhone

### A single photo in. An explorable 3D Gaussian splat out.

An experimental iPhone app that runs Apple's **SHARP** monocular view-synthesis
model on-device with **Core AI**, then renders the result interactively using
**RealityKit**.

[Getting started](#getting-started) · [How it works](#how-it-works) · [Project structure](#project-structure)

</div>

> [!IMPORTANT]
> SharpOnPhone targets **iOS 27** and uses prerelease Apple frameworks, including
> Core AI and RealityKit's Gaussian splat APIs. You will need a compatible Xcode
> beta, SDK, and physical device. APIs and setup may change between seeds.

## What it does

- Converts Apple's pretrained SHARP checkpoint into a Core AI `.aimodel`
- Runs FP16 inference locally on the device
- Reads camera focal length from the selected photo's EXIF metadata
- Converts SHARP's output tensors directly into RealityKit GPU buffers
- Displays the reconstructed scene as a depth-sorted Gaussian splat
- Supports drag-to-look, pinch-to-zoom, joystick movement, and view reset

The photo and model inference stay on the device; the app does not need a
network connection after it has been built and installed.

## How it works

```text
Photo Library
     │
     ├─ image pixels ──► resize + RGB FP16 tensor [1, 3, 1536, 1536]
     │
     └─ EXIF metadata ─► focal length ─► disparity factor
                                      │
                                      ▼
                              SHARP on Core AI
                                      │
                  ┌───────────────────┼───────────────────┐
                  ▼                   ▼                   ▼
             positions          scale/rotation      color/opacity
                  └───────────────────┼───────────────────┘
                                      ▼
                          RealityKit GPU buffers
                                      ▼
                         Interactive Gaussian splat
```

## Requirements

- macOS with a compatible Xcode beta
- iOS 27 SDK and an iOS 27 device
- Apple Silicon Mac recommended for model conversion
- [uv](https://docs.astral.sh/uv/) and Python 3.11+
- About 3 GB of free space for the SHARP checkpoint, plus additional space for
  the converted model and build artifacts

The app uses the increased-memory-limit entitlement. Your signing team and
provisioning profile must support it.

## Getting started

### 1. Clone the project and its conversion dependencies

```bash
git clone https://github.com/AryanRogye/SharpOnPhone.git
cd SharpOnPhone

git clone https://github.com/apple/ml-sharp.git
git clone https://github.com/apple/coreai-models.git
```

The two dependency repositories are intentionally ignored by Git.

### 2. Download the pretrained checkpoint

By downloading the model, you agree to Apple's
[SHARP model license](https://github.com/apple/ml-sharp/blob/main/LICENSE_MODEL).

```bash
curl -L \
  https://ml-site.cdn-apple.com/models/sharp/sharp_2572gikvuh.pt \
  -o sharp_2572gikvuh.pt
```

### 3. Create the Core AI model

```bash
uv venv .venv --python 3.11
uv pip install --python .venv/bin/python \
  -e ./coreai-models/python \
  -e ./ml-sharp

.venv/bin/python convert_sharp.py
cp -R sharp_model.aimodel SharpOnPhone/
```

Conversion exports the model with a fixed FP16 image input of
`[1, 3, 1536, 1536]`. Both the checkpoint and generated `.aimodel` are ignored
by Git because they are large artifacts.

### 4. Build and run

1. Open `SharpOnPhone.xcodeproj` in Xcode.
2. Select your own development team under **Signing & Capabilities**.
3. Choose a compatible physical iPhone.
4. Build and run.
5. Tap **Load Model**, choose a photo, then tap **Run Sharp**.
6. Open **View Gaussian Splat** to explore the result.

For the best result, use a sharp, well-lit photo from a camera that preserves
EXIF focal-length metadata. Screenshots and stripped images may fail because the
app cannot calculate the required disparity factor.

## Controls

| Gesture | Action |
| --- | --- |
| Drag | Rotate the reconstruction |
| Pinch | Zoom in or out |
| Joystick | Move laterally and in depth |
| Viewfinder button | Reset the view |

## Project structure

```text
SharpOnPhone/
├── SharpOnPhone/                 # App target, model runner, image preprocessing
│   ├── SharpRunner.swift         # Core AI loading, inference, and GPU buffers
│   └── sharp_model.aimodel/      # Generated locally; not committed
├── SharpOnPhoneUI/               # Local Swift package containing the interface
│   └── Sources/SharpOnPhoneUI/
│       ├── HomeScreen.swift
│       └── GaussianSplatView.swift
├── convert_sharp.py              # PyTorch SHARP → Core AI conversion
└── SharpOnPhone.xcodeproj
```

## Current limitations

- This is a research prototype built on beta APIs, not a production app.
- A photo must contain usable focal-length EXIF metadata.
- Input images are resized to a square, which may alter their aspect ratio.
- Model loading and inference are memory-intensive.
- There are currently no automated tests.

## Built with

- [SHARP](https://github.com/apple/ml-sharp) — monocular view synthesis
- [Core AI Models](https://github.com/apple/coreai-models) — model conversion
  and on-device inference
- [RealityKit](https://developer.apple.com/augmented-reality/realitykit/) —
  Gaussian splat rendering
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) — app interface

## Acknowledgements

SHARP and Core AI Models are projects from Apple. Model weights remain subject
to their upstream terms. This repository does not currently include a license
for the application source code.

