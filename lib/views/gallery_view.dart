import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:intellizoom/views/view_pictures.dart';

class GalleryPage extends StatefulWidget {
  final List<String> imagePaths;
  const GalleryPage({Key? key, required this.imagePaths}) : super(key: key);

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Captured Pictures'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0.0,
      ),
      body: Container(
          color: Colors.black,
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.only(bottom: 20),
          child: widget.imagePaths.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.imagePaths.length,
                    itemBuilder: (BuildContext context, int index) {
                      final path = widget.imagePaths[index];
                      return GestureDetector(
                        onDoubleTap: () {
                          setState(() {
                            File file = File(path);
                            file.delete();
                            widget.imagePaths.removeAt(index);
                          });
                        },
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PreviewPage(
                                        image: XFile(path),
                                      )));
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          child: Image.file(
                            File(path),
                            isAntiAlias: true,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const Center(
                  child: Text('No Images'),
                )),
    );
  }
}
