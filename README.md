# obj_cam

A Flutter project with intelligent auto-zoom for taking pictures of objects.
**Supported Platforms:**

|      | Android | iOS | Linux | Mac | Windows | Web |
|------|---------|-----|-------|-----|---------|-----|
| live | ✅       | ✅   |   [🚧](https://github.com/flutter/flutter/issues/41710)   |  [🚧](https://github.com/flutter/flutter/issues/41708)  |         |     |

## Overview

Object detection applies on an image stream from camera (portrait mode only for the showcase purpose).
All expensive and heavy operations are performed in a separate background isolate.

**Features:**

* Real-time/Live object detection (using TensorFlow Lite model)
* Automatic zoom adjustment for capturing objects in view.
* Slider control for adjusting zoom level with a reset button.
* Portrait mode camera support.
* Background isolate for smooth performance.

## Getting Started

Leverages the Live object detection example following [this](https://www.tensorflow.org/lite/examples/object_detection/overview).
The application is a simple demonstration of the [tflite_flutter](https://pub.dev/packages/tflite_flutter) package's sample code.

### Prerequisites

- Flutter SDK: Install from [here](https://flutter.dev/docs/get-started/install).
- Android Studio / Visual Studio Code: For Flutter development.
- Git: For version control.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/obj_cam.git
2. Navigate to the project directory:
   ```
   cd obj_cam
3. Run the download script to fetch TensorFlow Lite models:
   ```
   'sh ./scripts/download_model.sh' from your repo core folder to download tf models.
4. Open the project in your preferred IDE (Android Studio / Visual Studio Code). 
5. Connect a device or start an emulator. 
6. Run the app:
   ```
   flutter run

## Usage

1. Launch the app on your device. 
2. Aim the camera at an object you want to capture. 
3. Tap the capture button to take a picture with automatic zoom adjustment. 
4. Review the captured image on the display screen.

## How to start

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

**Additional Notes:**
* Landscape mode support is not planned as of yet.

**License:**
The included Live object detection example is licensed under the Apache License 2.0. See the LICENSE file for details.

**Acknowledgments:**
TensorFlow Lite team for providing the object detection example.
Flutter and Dart community for valuable resources and support.