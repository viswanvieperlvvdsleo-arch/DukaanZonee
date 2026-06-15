import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class B2BMediaDocsLinksPage extends StatelessWidget {
  const B2BMediaDocsLinksPage({
    super.key,
    required this.merchant,
    this.messages = const [],
    this.isGroup = false,
    this.groupData,
  });

  final Map<String, dynamic> merchant;
  final List<Map<String, dynamic>> messages;
  final bool isGroup;
  final Map<String, dynamic>? groupData;

  @override
  Widget build(BuildContext context) {
    // Dynamic theme-aware colors matching active application mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color lightGray = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color border = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final Color primaryGreen = const Color(0xFF10B981);

    // Parse actual messages for tabs
    final List<Map<String, dynamic>> mediaItems = [];
    final List<Map<String, dynamic>> docsItems = [];
    final List<Map<String, dynamic>> linksItems = [];

    for (final m in messages) {
      final String type = m['type'] ?? 'text';
      final String txt = m['message'] ?? '';
      final String? path =
          m['mediaPath']?.toString() ?? m['attachmentPath']?.toString();

      if (['image', 'photo', 'video', 'voice'].contains(type) &&
          path != null &&
          path.isNotEmpty) {
        mediaItems.add(m);
      } else if (['pdf', 'file'].contains(type)) {
        docsItems.add({
          'name': m['mediaName']?.toString() ?? txt,
          'size': m['attachmentSize'] ?? '142 KB',
          'date': m['time'] ?? 'Today',
          'path': path,
        });
      } else if (txt.contains('http://') ||
          txt.contains('https://') ||
          txt.contains('www.') ||
          txt.contains('.com')) {
        // Extract URL and descriptive text
        String urlString = 'https://dukaan_zone.com/docs';
        final match = RegExp(r'(https?://[^\s]+)').firstMatch(txt);
        if (match != null) {
          urlString = match.group(0) ?? urlString;
        }
        linksItems.add({
          'title': isGroup ? 'B2B Shared Resource' : 'Partner Reference URL',
          'url': urlString,
          'desc': txt,
        });
      }
    }

    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bg,
        cardColor: cardColor,
        colorScheme: ColorScheme(
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: primaryGreen,
          onPrimary: Colors.white,
          secondary: primaryGreen,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: cardColor,
          onSurface: textPrimary,
        ),
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 2,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isGroup ? (groupData?['name'] ?? 'Group') : merchant['name'],
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: textPrimary,
                fontSize: 16,
              ),
            ),
            bottom: TabBar(
              indicatorColor: primaryGreen,
              labelColor: primaryGreen,
              unselectedLabelColor: lightGray,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Media'),
                Tab(text: 'Docs'),
                Tab(text: 'Links'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildMediaTab(context, mediaItems, lightGray, border),
              _buildDocsTab(context, docsItems, cardColor, lightGray, border),
              _buildLinksTab(context, linksItems, cardColor, lightGray, border),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTab(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Color lightGray,
    Color border,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 48,
              color: lightGray.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No shared media files found.',
              style: TextStyle(color: lightGray, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final String type = item['type']?.toString() ?? 'image';
        final String? path =
            item['mediaPath']?.toString() ?? item['attachmentPath']?.toString();
        final bool isImage = type == 'image' || type == 'photo';
        return GestureDetector(
          onTap: path == null
              ? null
              : () => isImage
                    ? _openFullscreenImage(context, path)
                    : _showMediaNotice(context, type),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? ProductImageView(
                    imageUrl: path,
                    fallbackIcon: Icons.image_outlined,
                  )
                : Icon(
                    _iconFor(type),
                    color: const Color(0xFF10B981),
                    size: 34,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDocsTab(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Color cardColor,
    Color lightGray,
    Color border,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: lightGray.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No shared documents found.',
              style: TextStyle(color: lightGray, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = items[index];
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description, color: Colors.blue),
            ),
            title: Text(
              doc['name']!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              '${doc['size']} • ${doc['date']}',
              style: TextStyle(
                color: lightGray,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: Color(0xFF10B981),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading ${doc['name']}...')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Color cardColor,
    Color lightGray,
    Color border,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 48,
              color: lightGray.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No shared links found.',
              style: TextStyle(color: lightGray, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final link = items[index];
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link_rounded, color: Color(0xFF10B981)),
            ),
            title: Text(
              link['title']!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  link['url']!,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  link['desc']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: lightGray, fontSize: 11),
                ),
              ],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening link: ${link['url']}')),
              );
            },
          ),
        );
      },
    );
  }

  void _openFullscreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: Hero(
              tag: url,
              child: InteractiveViewer(
                child: ProductImageView(
                  imageUrl: url,
                  fallbackIcon: Icons.image_outlined,
                  defaultFit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaNotice(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_labelFor(type)} preview is saved in chat.')),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'video' => Icons.play_circle_outline_rounded,
      'voice' => Icons.mic_rounded,
      'pdf' || 'file' => Icons.picture_as_pdf_rounded,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  String _labelFor(String type) {
    return switch (type) {
      'video' => 'Video',
      'voice' => 'Voice note',
      'pdf' || 'file' => 'Document',
      _ => 'Media',
    };
  }
}
