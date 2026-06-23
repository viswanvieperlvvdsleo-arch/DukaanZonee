import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
import 'b2b_media_docs_links_page.dart';

class B2BContactInfoPage extends StatelessWidget {
  const B2BContactInfoPage({
    super.key,
    required this.merchant,
    this.messages = const [],
    this.onSearchClick,
    this.onStartVoiceCall,
    this.onStartVideoCall,
    this.isGroup = false,
    this.groupData,
  });

  final Map<String, dynamic> merchant;
  final List<Map<String, dynamic>> messages;
  final VoidCallback? onSearchClick;
  final VoidCallback? onStartVoiceCall;
  final VoidCallback? onStartVideoCall;
  final bool isGroup;
  final Map<String, dynamic>? groupData;

  @override
  Widget build(BuildContext context) {
    // Elegant theme-aware colors matching active application mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC); // Slate 900 vs Slate 50
    final Color cardColor = isDark
        ? const Color(0xFF1E293B)
        : Colors.white; // Slate 800 vs White
    final Color textPrimary = isDark
        ? Colors.white
        : const Color(0xFF0F172A); // Slate 900
    final Color lightGray = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B); // Slate 400 vs Slate 600
    final Color border = isDark
        ? Colors.white10
        : const Color(0xFFE2E8F0); // Slate 200

    final Color darkAccent = const Color(0xFF2563EB); // Royal Blue
    final Color primaryGreen = const Color(0xFF10B981); // Emerald Green
    final Color avatarBgColor =
        merchant['avatarColor'] as Color? ?? Colors.indigo;

    // Parse messages for actual attachments
    final List<Map<String, dynamic>> mediaList = [];
    final List<Map<String, dynamic>> docsList = [];
    final List<Map<String, dynamic>> linksList = [];

    for (final m in messages) {
      final String type = m['type'] ?? 'text';
      final String txt = m['message'] ?? '';
      if (type == 'photo' ||
          type == 'image' ||
          type == 'video' ||
          type == 'voice') {
        mediaList.add(m);
      } else if (type == 'file' || type == 'pdf') {
        docsList.add(m);
      } else if (txt.contains('http://') ||
          txt.contains('https://') ||
          txt.contains('www.') ||
          txt.contains('.com')) {
        linksList.add(m);
      }
    }
    final int totalCount =
        mediaList.length + docsList.length + linksList.length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isGroup ? 'Group info' : 'Contact info',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isGroup)
            IconButton(
              icon: Icon(Icons.more_vert, color: textPrimary),
              onPressed: () {},
            )
          else
            IconButton(
              icon: Icon(Icons.edit_outlined, color: textPrimary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Edit details is managed by the network administrator.',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 1. Profile Avatar & Name Header
            Center(
              child: Column(
                children: [
                  Hero(
                    tag:
                        'avatar-${isGroup ? (groupData?['name'] ?? 'Group') : merchant['name']}',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardColor,
                        border: Border.all(
                          color: avatarBgColor.withOpacity(0.4),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: avatarBgColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: avatarBgColor.withOpacity(0.15),
                          child: Text(
                            isGroup
                                ? (groupData?['name']?[0] ?? 'G')
                                : merchant['name'][0],
                            style: TextStyle(
                              color: avatarBgColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isGroup
                        ? (groupData?['name'] ?? 'Premium Wholesalers')
                        : merchant['name'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isGroup
                        ? 'B2B Group • ${groupData?['members']?.length ?? 4} participants'
                        : '${merchant['owner']} • B2B Partner',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: lightGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!isGroup)
                    Text(
                      '+91 00000 00000',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: lightGray.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Action buttons (Voice, Video, Search / Group settings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: isGroup
                          ? Icons.add_moderator
                          : Icons.phone_outlined,
                      label: isGroup ? 'Add Member' : 'Voice',
                      color: primaryGreen,
                      cardColor: cardColor,
                      textColor: textPrimary,
                      onTap: () {
                        if (!isGroup && onStartVoiceCall != null) {
                          onStartVoiceCall!();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isGroup
                                  ? 'Click Admin panel below to manage members.'
                                  : 'Starting Voice Call...',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: isGroup
                          ? Icons.notifications_none_rounded
                          : Icons.videocam_outlined,
                      label: isGroup ? 'Mute' : 'Video',
                      color: primaryGreen,
                      cardColor: cardColor,
                      textColor: textPrimary,
                      onTap: () {
                        if (!isGroup && onStartVideoCall != null) {
                          onStartVideoCall!();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isGroup
                                  ? 'Notifications Muted.'
                                  : 'Starting Video Call...',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.search,
                      label: 'Search',
                      color: primaryGreen,
                      cardColor: cardColor,
                      textColor: textPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        if (onSearchClick != null) onSearchClick!();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Dynamic Media, links and docs section
            _buildSectionCard(
              cardColor: cardColor,
              border: border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => push(
                      context,
                      B2BMediaDocsLinksPage(
                        merchant: merchant,
                        messages: messages,
                        isGroup: isGroup,
                        groupData: groupData,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.perm_media_outlined,
                                color: lightGray,
                                size: 20,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Media, links and docs',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '$totalCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: lightGray,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: lightGray,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Horizontally scrolling dynamic preview thumbnails
                  Container(
                    height: 80,
                    margin: const EdgeInsets.only(
                      left: 20,
                      bottom: 20,
                      right: 20,
                    ),
                    child: totalCount == 0
                        ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 16,
                                  color: lightGray,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No media, links, or docs shared.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: lightGray,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: totalCount,
                            itemBuilder: (context, idx) {
                              if (idx < mediaList.length) {
                                return _buildMediaThumbnail(
                                  imageUrl:
                                      'https://images.unsplash.com/photo-1610348725531-843dff10902c?w=150&auto=format&fit=crop',
                                  border: border,
                                );
                              }
                              idx -= mediaList.length;
                              if (idx < docsList.length) {
                                return _buildMediaThumbnail(
                                  isDoc: true,
                                  docType: 'PDF',
                                  border: border,
                                );
                              }
                              return _buildMediaThumbnail(
                                isDoc: false,
                                docType: 'URL',
                                border: border,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 4. Group Members List (If Group Chat)
            if (isGroup)
              _buildSectionCard(
                cardColor: cardColor,
                border: border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        top: 16.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        '${groupData?['members']?.length ?? 4} members in group',
                        style: TextStyle(
                          color: lightGray,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ...(groupData?['members'] as List<dynamic>? ?? []).map((m) {
                      final bool isAdmin = m['isAdmin'] == true;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryGreen.withOpacity(0.12),
                          child: Text(
                            m['name']?[0] ?? 'M',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                        title: Text(
                          m['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          isAdmin
                              ? 'Group Admin • Tap to manage'
                              : 'Member • Tap to promote',
                          style: TextStyle(color: lightGray, fontSize: 11),
                        ),
                        trailing: isAdmin
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: primaryGreen.withOpacity(0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          // Allow admin settings promotion directly from member list
                          if (groupData?['isAdminOfGroup'] == true) {
                            _showAdminMemberOptions(context, m, groupData!);
                          }
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),

            if (isGroup) const SizedBox(height: 12),

            // 5. WhatsApp Style Options list
            _buildSectionCard(
              cardColor: cardColor,
              border: border,
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.star_border_rounded,
                    title: 'Starred messages',
                    lightGray: lightGray,
                    textColor: textPrimary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Starred messages is empty.'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _buildOptionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification settings',
                    lightGray: lightGray,
                    textColor: textPrimary,
                    onTap: () {},
                  ),
                  if (isGroup && groupData?['isAdminOfGroup'] == true) ...[
                    const Divider(height: 1, color: Colors.white10),
                    _buildOptionTile(
                      icon: Icons.settings_applications,
                      title: 'Group Settings & Permissions',
                      subtitle:
                          'Control roles, message rules, and settings overrides.',
                      lightGray: lightGray,
                      textColor: textPrimary,
                      onTap: () {
                        // Open B2B Group Settings Page
                        push(
                          context,
                          B2BGroupSettingsPage(groupData: groupData!),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 1, color: Colors.white10),
                  _buildOptionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Encryption',
                    subtitle:
                        'B2B messaging runs on DukaanZone secure Ledger routing.',
                    lightGray: lightGray,
                    textColor: textPrimary,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showAdminMemberOptions(
    BuildContext context,
    Map<String, dynamic> member,
    Map<String, dynamic> gData,
  ) {
    final bool isAdmin = member['isAdmin'] == true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage ${member['name']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Administration panel controls',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.add_moderator,
                  color: primary,
                ),
                title: Text(
                  isAdmin ? 'Dismiss as Admin' : 'Promote to Group Admin',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  member['isAdmin'] = !isAdmin;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${member['name']} status updated successfully.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text(
                  'Remove from Group',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  (gData['members'] as List<dynamic>).removeWhere(
                    (m) => m['name'] == member['name'],
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${member['name']} removed.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    required Color cardColor,
    required Color border,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }

  Widget _buildMediaThumbnail({
    String? imageUrl,
    bool isAudio = false,
    bool isDoc = false,
    String? docType,
    required Color border,
  }) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: isDoc
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.description,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          docType ?? 'PDF',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Colors.teal,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          docType ?? 'URL',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            )
          : null,
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color lightGray,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: lightGray),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: lightGray.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: lightGray.withOpacity(0.5),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
