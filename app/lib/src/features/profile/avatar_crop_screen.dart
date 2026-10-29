import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-screen "move and scale" step for a new profile photo (like
/// WhatsApp): drag and pinch the picture inside a circle, then
/// [Navigator.pop] with a 640×640 PNG of what the square shows.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.bytes});

  final Uint8List bytes;

  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) =>
      Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AvatarCropScreen(bytes: bytes),
        ),
      );

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  static const _outputSize = 640.0;

  final _boundary = GlobalKey();
  final _transform = TransformationController();
  double? _aspect; // width / height of the picture
  double? _side; // the square's size the transform was centred for
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.bytes).then((img) {
      if (mounted) setState(() => _aspect = img.width / img.height);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// The picture's size so it just covers the square.
  Size _coverSize(double side) => _aspect! >= 1
      ? Size(side * _aspect!, side)
      : Size(side, side / _aspect!);

  Future<void> _done() async {
    setState(() => _saving = true);
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: _outputSize / boundary.size.width,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop(data!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Move and scale'),
        actions: [
          TextButton(
            onPressed: _aspect == null || _saving ? null : _done,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Use photo'),
          ),
        ],
      ),
      body: _aspect == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, c) {
                final side = math.min(c.maxWidth, c.maxHeight) - 32;
                final cover = _coverSize(side);
                if (_side != side) {
                  // Start centred on the picture.
                  _side = side;
                  _transform.value = Matrix4.translationValues(
                    -(cover.width - side) / 2,
                    -(cover.height - side) / 2,
                    0,
                  );
                }
                return Center(
                  child: SizedBox.square(
                    dimension: side,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _boundary,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _transform,
                              constrained: false,
                              minScale: 1,
                              maxScale: 6,
                              child: Image.memory(
                                widget.bytes,
                                width: cover.width,
                                height: cover.height,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _CircleMask()),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Drag to move · pinch or scroll to zoom',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// Dims the corners outside the circle the avatar will show.
class _CircleMask extends CustomPainter {
  const _CircleMask();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(rect), circle),
      Paint()..color = Colors.black54,
    );
    canvas.drawPath(
      circle,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CircleMask oldDelegate) => false;
}
