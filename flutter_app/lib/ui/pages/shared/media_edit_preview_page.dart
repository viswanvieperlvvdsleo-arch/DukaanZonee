import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

class MediaEditPreviewPage extends StatefulWidget {
  const MediaEditPreviewPage({super.key, required this.image});
  final XFile image;

  @override
  State<MediaEditPreviewPage> createState() => _MediaEditPreviewPageState();
}

class _MediaEditPreviewPageState extends State<MediaEditPreviewPage> {
  final _captionController = TextEditingController();
  final GlobalKey _globalKey = GlobalKey();
  
  bool _isDrawingMode = false;
  Color _selectedColor = Colors.red;
  final List<Stroke> _strokes = [];
  Stroke? _currentStroke;

  final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.white,
    Colors.black,
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!_isDrawingMode) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke = Stroke(color: _selectedColor, points: [offset]);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode || _currentStroke == null) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke!.points.add(offset);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawingMode || _currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  Future<void> _saveAndSend() async {
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes != null) {
        if (!mounted) return;
        Navigator.pop(context, {
          'bytes': bytes,
          'caption': _captionController.text,
        });
      }
    } catch (e) {
      debugPrint('Failed to save edited image: $e');
      if (!mounted) return;
      Navigator.pop(context, {
        'bytes': null,
        'caption': _captionController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      if (_isDrawingMode)
                        IconButton(
                          icon: const Icon(Icons.undo, color: Colors.white),
                          onPressed: _undo,
                        ),
                      IconButton(
                        icon: Icon(
                          _isDrawingMode ? Icons.edit_off : Icons.edit,
                          color: _isDrawingMode ? _selectedColor : Colors.white,
                        ),
                        onPressed: () => setState(() => _isDrawingMode = !_isDrawingMode),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Color picker
            if (_isDrawingMode)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
            const SizedBox(height: 16),
            
            // Image & Drawing Area
            Expanded(
              child: RepaintBoundary(
                key: _globalKey,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List>(
                        future: widget.image.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                            );
                          }
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        },
                      ),
                      CustomPaint(
                        painter: DrawingPainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                        size: Size.infinite,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: _saveAndSend,
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Stroke {
  final Color color;
  final List<Offset> points;
  Stroke({required this.color, required this.points});
}

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }
  }

  void _paintStroke(Canvas canvas, Stroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    if (stroke.points.length == 1) {
      canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
    } else {
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
