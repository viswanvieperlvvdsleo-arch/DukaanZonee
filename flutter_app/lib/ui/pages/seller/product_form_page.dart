import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ProductFormPage extends StatefulWidget {
  final String? initialName;
  final String? initialCategory;
  final String? initialBarcode;
  final String? initialDescription;
  final String? initialImageUrl;
  final double? initialPrice;
  final int? initialStock;

  const ProductFormPage({
    super.key,
    this.initialName,
    this.initialCategory,
    this.initialBarcode,
    this.initialDescription,
    this.initialImageUrl,
    this.initialPrice,
    this.initialStock,
  });

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _nameController = TextEditingController();
  final _rateController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _thresholdController = TextEditingController(text: '3');
  final _descController = TextEditingController();

  bool _alertEnabled = true;
  bool _loadingAi = false;
  bool _publishing = false;

  String? _selectedImagePath;
  BoxFit _imageFit = BoxFit.cover;
  double _cropX = 0;
  double _cropY = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _categoryController.text = widget.initialCategory ?? '';
    _barcodeController.text = widget.initialBarcode ?? '';
    _descController.text = widget.initialDescription ?? '';
    _rateController.text = widget.initialPrice == null
        ? ''
        : widget.initialPrice!.toStringAsFixed(
            widget.initialPrice! % 1 == 0 ? 0 : 2,
          );
    _stockController.text = widget.initialStock?.toString() ?? '';
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      _selectedImagePath = widget.initialImageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _barcodeController.dispose();
    _thresholdController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 72,
      );
      if (selected != null) {
        final bytes = await selected.readAsBytes();
        final mimeType = selected.mimeType ?? _mimeTypeForPath(selected.path);
        setState(() {
          _selectedImagePath = 'data:$mimeType;base64,${base64Encode(bytes)}';
          _imageFit = BoxFit.cover;
          _cropX = 0;
          _cropY = 0;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error selecting image: $e")));
    }
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String? get _imageToPublish {
    final image = _selectedImagePath;
    if (image == null || image.isEmpty) return null;
    final fit = _imageFit == BoxFit.contain ? 'contain' : 'cover';
    return '$image#dzcrop=fit=$fit&x=${_cropX.toStringAsFixed(2)}&y=${_cropY.toStringAsFixed(2)}';
  }

  void _generateAiDescription() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an item name first!")),
      );
      return;
    }
    setState(() => _loadingAi = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _loadingAi = false;
      _descController.text =
          "Sourced directly from local organic farms, these premium quality ${_nameController.text} are handpicked at peak ripeness. Naturally rich in nutrients and absolutely fresh. Perfect for health-conscious homes and daily meals.";
    });
  }

  Future<void> _publishProduct() async {
    final name = _nameController.text.trim();
    final rate = _rateController.text.trim();
    final stockVal = _stockController.text.trim();
    final thresholdVal = _thresholdController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || rate.isEmpty || stockVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in Name, Rate, and Stock count!"),
        ),
      );
      return;
    }

    final doublePrice = double.tryParse(rate) ?? 0.0;
    final intStock = int.tryParse(stockVal) ?? 0;
    final threshold = int.tryParse(thresholdVal) ?? 3;

    final imageToShow = _imageToPublish;

    setState(() => _publishing = true);
    try {
      final newProduct = await sellerBackendService.createItem(
        name: name,
        price: doublePrice,
        stock: intStock,
        category: _categoryController.text,
        barcode: _barcodeController.text,
        description: desc,
        imageUrl: imageToShow,
        alertThreshold: threshold,
        alertEnabled: _alertEnabled,
        isActive: true,
      );
      catalogProducts.insert(0, newProduct);
      if (!mounted) return;
      Navigator.pop(context, newProduct);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not publish item: $error')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Add to Shelf',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Kicker('VISUAL IDENTITY'),
            const SizedBox(height: 12),
            if (_selectedImagePath != null)
              Column(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: shadowSm,
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ProductImageView(
                              imageUrl: _imageToPublish,
                              fallbackIcon: Icons.shopping_bag_outlined,
                              fallbackIconSize: 56,
                              defaultFit: _imageFit,
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FloatingActionButton.extended(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              label: const Text(
                                'Change Photo',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              icon: const Icon(Icons.photo_library_outlined),
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildCropControls(),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickImage(ImageSource.camera),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: primary.withOpacity(0.3)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: primary,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Open Live Lens',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickImage(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: primary.withOpacity(0.1)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: muted,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),

            const Kicker('FULFILLMENT DETAILS'),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rate (₹)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Stock Count',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode / SKU',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Low Stock Alert',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Kicker('AI MARKETING COPY'),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your product...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadingAi ? null : _generateAiDescription,
                icon: _loadingAi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Generate with Genkit AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Kicker('INVENTORY SIGNALS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Critical Restock Alert',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Send Voice Signal to neighbors when restocked',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _alertEnabled,
                    onChanged: (v) => setState(() => _alertEnabled = v),
                    activeColor: primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            _publishing
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    'Publish to Shelf',
                    Icons.cloud_upload_outlined,
                    _publishProduct,
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCropControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card crop adjustment',
            style: TextStyle(fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Fill card'),
                selected: _imageFit == BoxFit.cover,
                onSelected: (_) => setState(() => _imageFit = BoxFit.cover),
              ),
              ChoiceChip(
                label: const Text('Fit full image'),
                selected: _imageFit == BoxFit.contain,
                onSelected: (_) => setState(() => _imageFit = BoxFit.contain),
              ),
            ],
          ),
          if (_imageFit == BoxFit.cover) ...[
            const SizedBox(height: 10),
            const Text(
              'Horizontal position',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _cropX,
              min: -1,
              max: 1,
              onChanged: (value) => setState(() => _cropX = value),
            ),
            const Text(
              'Vertical position',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _cropY,
              min: -1,
              max: 1,
              onChanged: (value) => setState(() => _cropY = value),
            ),
          ],
        ],
      ),
    );
  }
}
