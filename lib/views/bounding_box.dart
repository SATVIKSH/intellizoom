import 'package:flutter/material.dart';

const kColors = [Colors.orange, Colors.green, Colors.blue];

// ignore: must_be_immutable
class BorderBox extends StatelessWidget {
  BorderBox(
      {super.key,
      required this.recognition,
      required this.constraints,
      required this.index,
      required this.zoom});
  int index;
  Rect? boundingBox;
  final recognition;
  final void Function(Map recognition, int index) zoom;
  BoxConstraints constraints;
  @override
  Widget build(BuildContext context) {
    double height = constraints.maxHeight;

    double width = constraints.maxWidth;

    boundingBox = Rect.fromLTWH(
        recognition['rect']['x'] * width,
        recognition['rect']['y'] * height,
        recognition['rect']['w'] * width,
        recognition['rect']['h'] * height);
    zoom(recognition, index);
    print('recognitions $boundingBox');
    return boundingBox != null
        ? Positioned(
            left: boundingBox!.left,
            top: boundingBox!.top,
            width: boundingBox!.width,
            height: boundingBox!.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: kColors[index], width: 2.0),
              ),
            ),
          )
        : const Positioned(
            child: SizedBox(
            height: 0,
            width: 0,
          ));
  }
}
