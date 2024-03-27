/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

// ImageUtils
// class ImageUtils {

/// Converts a [CameraImage] in YUV420 format to [imageLib.Image] in RGB format
Future<image_lib.Image?> convertCameraImageToImage(
    CameraImage cameraImage) async {
  if (cameraImage.format.group == ImageFormatGroup.yuv420) {
    return convertYUV420ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
    return convertBGRA8888ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
    return convertJPEGToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
    return convertNV21ToImage(cameraImage);
  } else {
    return null;
  }
}

// Converts a [CameraImage] in BGRA888 format to [imageLib.Image] in RGB format
image_lib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
  image_lib.Image img = image_lib.Image.fromBytes(
      width: cameraImage.planes[0].width!,
      height: cameraImage.planes[0].height!,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: image_lib.ChannelOrder.bgra);
  return img;
}

image_lib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image = image_lib.Image(width: imageWidth, height: imageHeight);

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      // Y plane should have positive values belonging to [0...255]
      final int y = yBuffer[yIndex];

      // U/V Values are subsampled i.e. each pixel in U/V chanel in a
      // YUV_420 image act as chroma value for 4 neighbouring pixels
      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
      // [0, 255] range they are scaled up and centered to 128.
      // Operation below brings U/V values to [-128, 127].
      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      // Compute RGB values per formula above.
      int r = (y + v * 1436 / 1024 - 179).round();
      int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (y + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      image.setPixelRgb(w, h, r, g, b);
    }
  }
  return image;
}

image_lib.Image convertJPEGToImage(CameraImage cameraImage) {
  // Extract the bytes from the CameraImage
  final bytes = cameraImage.planes[0].bytes;

  // Create a new Image instance from the JPEG bytes
  final image = image_lib.decodeImage(bytes);

  return image!;
}

image_lib.Image convertNV21ToImage(CameraImage cameraImage) {
  // Extract the bytes from the CameraImage
  final yuvBytes = cameraImage.planes[0].bytes;
  final vuBytes = cameraImage.planes[1].bytes;

  // Create a new Image instance
  final image = image_lib.Image(
    width: cameraImage.width,
    height: cameraImage.height,
  );

  // Convert NV21 to RGB
  convertNV21ToRGB(
    yuvBytes,
    vuBytes,
    cameraImage.width,
    cameraImage.height,
    image,
  );

  return image;
}

void convertNV21ToRGB(Uint8List yuvBytes, Uint8List vuBytes, int width,
    int height, image_lib.Image image) {
  // Conversion logic from NV21 to RGB
  // ...

  // Example conversion logic using the `imageLib` package
  // This is just a placeholder and may not be the most efficient method
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yIndex = y * width + x;
      final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

      final yValue = yuvBytes[yIndex];
      final uValue = vuBytes[uvIndex * 2];
      final vValue = vuBytes[uvIndex * 2 + 1];

      // Convert YUV to RGB
      final r = yValue + 1.402 * (vValue - 128);
      final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
      final b = yValue + 1.772 * (uValue - 128);

      // Set the RGB pixel values in the Image instance
      image.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), 255);
    }
  }
}

// }
