import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'package:dukaan_zone_flutter/services/voice_recorder/voice_recorder.dart';
import 'custom_camera_page.dart' as custom_camera;

/// Reusable Media Input Bar for B2B Chat, Seller Payment Chat, and User Payment Chat.
/// It provides message input, attachment options (Images, Videos, PDFs, Voice Recorder),
/// and manages preview screens with crop, trim, and player capabilities.
class MediaInputBar extends StatefulWidget {
  const MediaInputBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSend,
    required this.onMediaSent,
    this.onPayTap,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSend;
  final void Function(String type, String path, Map<String, dynamic>? extra)
  onMediaSent;
  final VoidCallback? onPayTap;

  @override
  State<MediaInputBar> createState() => _MediaInputBarState();
}

class _MediaInputBarState extends State<MediaInputBar> {
  final _picker = ImagePicker();

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Share Media',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 16,
              spacing: 12,
              children: [
                AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCustomCamera();
                  },
                ),
                AttachOption(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  color: primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImages();
                  },
                ),
                AttachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
                AttachOption(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'Document',
                  color: primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocument();
                  },
                ),
                AttachOption(
                  icon: Icons.mic_rounded,
                  label: 'Voice',
                  color: primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _startVoiceRecording();
                  },
                ),
                if (widget.onPayTap != null)
                  AttachOption(
                    icon: Icons.payment_rounded,
                    label: 'Pay',
                    color: success,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onPayTap!.call();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomCamera() async {
    if (!mounted) return;
    final result = await push<Map<String, dynamic>>(
      context,
      const custom_camera.CustomCameraPage(),
    );
    if (result != null && result['bytes'] != null) {
      final bytes = result['bytes'] as Uint8List;
      final file = XFile.fromData(bytes, name: 'edited_camera.png', mimeType: 'image/png');
      
      final media = await _prepareDataUrl(
        file,
        fallbackPath: 'edited_camera.png',
        fallbackMime: 'image/png', 
      );
      widget.onMediaSent('image', media.url, {
        'caption': result['caption'],
        'mediaName': media.name,
        'mediaMime': media.mime,
        'mediaSizeBytes': media.sizeBytes,
        'sizeBytes': media.sizeBytes,
      });
    }
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    if (!mounted) return;

    final result = await push<Map<String, dynamic>>(
      context,
      ImagePreviewScreen(files: files),
    );
    if (result != null) {
      final selectedPath = result['path']?.toString() ?? files.first.path;
      final selectedIndex = result['selectedIndex'] as int? ?? 0;
      final safeIndex = selectedIndex.clamp(0, files.length - 1).toInt();
      final fallbackFile = files[safeIndex];
      final selectedFile = selectedPath.startsWith('blob:')
          ? fallbackFile
          : XFile(selectedPath);
      final media = await _prepareDataUrl(
        selectedFile,
        fallbackPath: selectedPath,
        fallbackMime: _imageMimeForPath(selectedPath),
      );
      widget.onMediaSent('image', media.url, {
        'caption': result['caption'],
        'count': result['count'],
        'mediaName': media.name,
        'mediaMime': media.mime,
        'mediaSizeBytes': media.sizeBytes,
        'sizeBytes': media.sizeBytes,
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (file == null) return;
    if (!mounted) return;

    final result = await push<Map<String, dynamic>>(
      context,
      VideoPreviewScreen(path: file.path),
    );
    if (result != null) {
      final media = await _prepareDataUrl(
        file,
        fallbackPath: result['path']?.toString() ?? file.path,
        fallbackMime: _videoMimeForPath(file.path),
      );
      widget.onMediaSent('video', media.url, {
        'caption': result['caption'],
        'duration': result['duration'],
        'mediaName': media.name,
        'mediaMime': media.mime,
        'mediaSizeBytes': media.sizeBytes,
        'mediaDurationSeconds': result['duration'],
        'sizeBytes': media.sizeBytes,
      });
    }
  }

  Future<void> _pickDocument() async {
    if (!mounted) return;
    final result = await push<Map<String, dynamic>>(
      context,
      const DocumentPreviewScreen(),
    );
    if (result != null) {
      widget.onMediaSent('pdf', result['path'], {
        'caption': result['name'],
        'mediaName': result['name'],
        'mediaMime': 'application/pdf',
        'mediaSizeBytes': 340000,
        'sizeBytes': 340000,
      });
    }
  }

  void _startVoiceRecording() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => VoiceRecorderSheet(
        onSend: (seconds, note) {
          final fallbackName =
              'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
          final path = note.dataUrl.isNotEmpty
              ? note.dataUrl
              : '/DukaanZone/Media/Voice/$fallbackName';
          widget.onMediaSent('voice', path, {
            'mediaName': 'Voice note',
            'mediaMime': note.mimeType,
            'mediaDurationSeconds': seconds,
            'duration': seconds,
            'mediaSizeBytes': note.sizeBytes,
            'sizeBytes': note.sizeBytes,
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: _showAttachmentSheet,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  color: primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    hintStyle: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: navGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PreparedMedia> _prepareDataUrl(
    XFile file, {
    required String fallbackPath,
    required String fallbackMime,
    int maxBytes = 8 * 1024 * 1024,
  }) async {
    final name = file.name.isNotEmpty
        ? file.name
        : _fileNameFromPath(fallbackPath);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxBytes) {
        return _PreparedMedia(
          url: fallbackPath,
          name: name,
          mime: fallbackMime,
          sizeBytes: bytes.length,
        );
      }
      return _PreparedMedia(
        url: 'data:$fallbackMime;base64,${base64Encode(bytes)}',
        name: name,
        mime: fallbackMime,
        sizeBytes: bytes.length,
      );
    } catch (error) {
      debugPrint('Media encode failed: $error');
      return _PreparedMedia(
        url: fallbackPath,
        name: name,
        mime: fallbackMime,
        sizeBytes: 0,
      );
    }
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty || parts.last.isEmpty ? 'media' : parts.last;
  }

  String _imageMimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _videoMimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
  }
}

class _PreparedMedia {
  const _PreparedMedia({
    required this.url,
    required this.name,
    required this.mime,
    required this.sizeBytes,
  });

  final String url;
  final String name;
  final String mime;
  final int sizeBytes;
}

class AttachOption extends StatelessWidget {
  const AttachOption({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Image Preview Screen with swipeable carousel and ImageCropper editing integration.
class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({super.key, required this.files});
  final List<XFile> files;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _captionController = TextEditingController();
  late List<String> _paths;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _paths = widget.files.map((f) => f.path).toList();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _cropImage() async {
    final sourcePath = _paths[_currentIndex];
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Rotate',
            toolbarColor: const Color(0xFF10B981),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop & Rotate'),
          WebUiSettings(context: context),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _paths[_currentIndex] = croppedFile.path;
        });
      }
    } catch (e) {
      debugPrint("Error cropping image: $e");
    }
  }

  Widget _buildImageView(String path) {
    if (path.startsWith('/DukaanZone')) {
      return const Center(
        child: Icon(Icons.image_rounded, size: 80, color: Colors.white38),
      );
    }
    if (kIsWeb) {
      return Image.network(path, fit: BoxFit.contain);
    } else {
      return Image.file(File(path), fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${_paths.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
            tooltip: 'Crop / Edit',
            onPressed: _cropImage,
          ),
          if (_paths.length > 1)
            IconButton(
              icon: const Icon(
                Icons.photo_library_rounded,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: _paths.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) => Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey.shade900,
                  ),
                  child: _buildImageView(_paths[i]),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context, {
                    'path': _paths[_currentIndex],
                    'caption': _captionController.text.trim(),
                    'count': _paths.length,
                    'selectedIndex': _currentIndex,
                  }),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Video Preview Screen with trim control range sliders.
class VideoPreviewScreen extends StatefulWidget {
  const VideoPreviewScreen({super.key, required this.path});
  final String path;

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  final _captionController = TextEditingController();
  double _startTrim = 0.0;
  double _endTrim = 1.0;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Video Preview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    size: 80,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trim Video (UI Visual Only)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                RangeSlider(
                  values: RangeValues(_startTrim, _endTrim),
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() {
                    _startTrim = v.start;
                    _endTrim = v.end;
                  }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start: ${(_startTrim * 60).toInt()}s',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'End: ${(_endTrim * 60).toInt()}s',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
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
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context, {
                    'path': widget.path,
                    'caption': _captionController.text.trim(),
                    'duration': ((_endTrim - _startTrim) * 60).toInt(),
                  }),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Document Picker Screen showing mock PDFs.
class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({super.key});

  static const List<Map<String, String>> _mockDocs = [
    {
      'name': 'Invoice_March_2025.pdf',
      'size': '340 KB',
      'path': '/DukaanZone/Docs/Invoice_March_2025.pdf',
    },
    {
      'name': 'Supplier_Agreement.pdf',
      'size': '128 KB',
      'path': '/DukaanZone/Docs/Supplier_Agreement.pdf',
    },
    {
      'name': 'Cargo_Dispatch_Oats.pdf',
      'size': '95 KB',
      'path': '/DukaanZone/Docs/Cargo_Dispatch_Oats.pdf',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Document',
          style: TextStyle(fontWeight: FontWeight.w900, color: ink),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mockDocs.length,
        itemBuilder: (context, i) {
          final doc = _mockDocs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: shadowSm,
            ),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              title: Text(
                doc['name']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                doc['size']!,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              trailing: ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'path': doc['path'],
                  'name': doc['name'],
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Voice Recorder Bottom Sheet with timer, animated pulse, and audioplayers-backed preview playback.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key, required this.onSend});
  final void Function(int seconds, RecordedVoiceNote note) onSend;

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _recordingReady = false;
  int _seconds = 0;
  String? _errorMessage;
  RecordedVoiceNote? _recordedNote;
  Timer? _timer;
  late final BrowserVoiceRecorder _recorder;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Audioplayers integration
  late final AudioPlayer _audioPlayer;
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingPreview = state == PlayerState.playing;
      });
    });

    _recorder = BrowserVoiceRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordingReady = false;
      _errorMessage = null;
      _seconds = 0;
    });
    try {
      await _recorder.start();
      if (!mounted) return;
      setState(() => _recordingReady = true);
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _seconds++),
      );
    } catch (error) {
      if (!mounted) return;
      _pulseController.stop();
      setState(() {
        _isRecording = false;
        _recordingReady = false;
        _errorMessage =
            'Could not access microphone. Allow mic permission and try again.';
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _pulseController.stop();
    try {
      final note = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _recordedNote = note;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _hasRecorded = false;
        _errorMessage = 'Voice note could not be saved. Please try again.';
      });
    }
  }

  void _togglePlayPreview() async {
    if (_isPlayingPreview) {
      await _audioPlayer.pause();
    } else {
      try {
        final note = _recordedNote;
        if (note == null || note.dataUrl.isEmpty) return;
        await _audioPlayer.play(UrlSource(note.dataUrl));
      } catch (e) {
        debugPrint("Error playing preview: $e");
      }
    }
  }

  String get _durStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Voice Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isRecording) ...[
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _durStr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Recording...',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _recordingReady ? _stopRecording : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text(
                  'Stop Recording',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
              ),
            ] else if (_hasRecorded) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _togglePlayPreview,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlayingPreview
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: primary,
                            size: 20,
                          ),
                          Text(
                            _durStr,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Discard',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final note = _recordedNote;
                        if (note == null) return;
                        Navigator.pop(context);
                        widget.onSend(_seconds, note);
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Send',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
