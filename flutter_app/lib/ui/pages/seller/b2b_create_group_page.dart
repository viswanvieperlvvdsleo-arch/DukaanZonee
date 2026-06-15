import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dukaan_zone_flutter/dukaan.dart';

class B2BCreateGroupPage extends StatefulWidget {
  const B2BCreateGroupPage({super.key});

  @override
  State<B2BCreateGroupPage> createState() => _B2BCreateGroupPageState();
}

class _B2BCreateGroupPageState extends State<B2BCreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _selectedPartners = {};
  final List<Map<String, dynamic>> _partners = [];
  bool _loadingPartners = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners({String query = ''}) async {
    setState(() => _loadingPartners = true);
    try {
      final encoded = Uri.encodeQueryComponent(query.trim());
      final suffix = encoded.isEmpty ? '' : '?q=$encoded';
      final data = await apiClient.getJson('/api/seller/b2b/partners$suffix');
      final partners = (data['partners'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => _partnerFromBackend(Map<String, dynamic>.from(raw)))
          .toList();
      if (!mounted) return;
      setState(() {
        _partners
          ..clear()
          ..addAll(partners);
        _loadingPartners = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPartners = false);
    }
  }

  Map<String, dynamic> _partnerFromShop(Shop shop) {
    final palette = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.blueGrey,
      Colors.green,
    ];
    final color = palette[shop.name.hashCode.abs() % palette.length];
    return {
      'shopId': shop.id,
      'name': shop.name,
      'owner': shop.name,
      'specialty': '${shop.type} • ${shop.block}',
      'avatarUrl': shop.avatarUrl,
      'avatarColor': color,
    };
  }

  void _queuePartnerSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _loadPartners(query: value),
    );
  }

  String _partnerKey(Map<String, dynamic> partner) =>
      partner['shopId']?.toString() ?? partner['sellerId']?.toString() ?? '';

  Map<String, dynamic> _partnerFromBackend(Map<String, dynamic> partner) {
    final palette = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.blueGrey,
      Colors.green,
    ];
    final name = partner['name']?.toString() ?? 'Shop';
    final category = partner['category']?.toString() ?? 'Local shop';
    final block = partner['block']?.toString() ?? '';
    final color = palette[name.hashCode.abs() % palette.length];
    return {
      'shopId': partner['shopId']?.toString(),
      'sellerId': partner['sellerId']?.toString(),
      'name': name,
      'owner': partner['owner']?.toString() ?? name,
      'specialty': block.isEmpty ? category : '$category - $block',
      'email': partner['email']?.toString() ?? '',
      'phone': partner['phone']?.toString() ?? '',
      'upiId': partner['upiId']?.toString() ?? '',
      'avatarUrl': partner['avatarUrl']?.toString(),
      'avatarColor': color,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color lightGray = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color border = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final Color primaryGreen = const Color(0xFF10B981);

    final filtered = _partners.where((p) {
      final name = p['name'].toString().toLowerCase();
      final owner = p['owner'].toString().toLowerCase();
      final specialty = p['specialty'].toString().toLowerCase();
      final email = p['email'].toString().toLowerCase();
      final phone = p['phone'].toString().toLowerCase();
      final upiId = p['upiId'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          owner.contains(query) ||
          specialty.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          upiId.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create B2B Group',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textPrimary,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Group Identity Inputs
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: primaryGreen.withOpacity(0.12),
                        child: Icon(
                          Icons.group_add,
                          color: primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter group subject...',
                            labelText: 'Group Name',
                            labelStyle: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: lightGray,
                              fontSize: 13,
                            ),
                          ),
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white10),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Provide a brief B2B collaboration agenda...',
                      labelText: 'Description',
                      labelStyle: TextStyle(
                        color: lightGray,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: lightGray.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Select Participants Section
            Text(
              'SELECT COLLABORATORS',
              style: TextStyle(
                color: lightGray,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _queuePartnerSearch,
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: primaryGreen, size: 20),
                  hintText: 'Search partners...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: lightGray, fontSize: 13),
                ),
                style: TextStyle(color: textPrimary, fontSize: 13.5),
              ),
            ),

            const SizedBox(height: 12),

            // Partner Checklist Card
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  if (_loadingPartners)
                    const Padding(
                      padding: EdgeInsets.all(34.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off_rounded,
                            color: lightGray.withOpacity(0.4),
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _partners.isEmpty
                                ? 'No backend seller accounts found yet.'
                                : 'No accounts match search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: lightGray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final key = _partnerKey(p);
                        final bool isSelected = _selectedPartners.containsKey(key);
                        return CheckboxListTile(
                          activeColor: primaryGreen,
                          title: Text(
                            p['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            p['specialty'],
                            style: TextStyle(color: lightGray, fontSize: 11),
                          ),
                          value: isSelected,
                          onChanged: (bool? val) {
                            setState(() {
                              if (val == true) {
                                _selectedPartners[key] = p;
                              } else {
                                _selectedPartners.remove(key);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            radius: 18,
                            backgroundColor: (p['avatarColor'] as Color)
                                .withOpacity(0.15),
                            child: ClipOval(
                              child: ProductImageView(
                                imageUrl: p['avatarUrl']?.toString(),
                                fallbackIcon: Icons.storefront_outlined,
                                fallbackIconSize: 18,
                                fallbackColor: p['avatarColor'] as Color,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. Glowing Create Button
            GestureDetector(
              onTap: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a group subject name.'),
                    ),
                  );
                  return;
                }

                // Return created group details back to the caller
                final List<Map<String, dynamic>> finalMembers = [
                  {'name': 'You', 'isAdmin': true},
                  ..._selectedPartners
                      .values
                      .map((p) => {'name': p['name'], 'isAdmin': false})
                      .toList(),
                ];

                final Map<String, dynamic> newGroup = {
                  'name': name,
                  'description': _descController.text.trim(),
                  'members': finalMembers,
                  'isAdminOfGroup': true,
                  'avatarColor': Colors.teal,
                  'isGroup': true,
                  'permissions': {
                    'sendMessagesOnlyAdmins': false,
                    'editSettingsOnlyAdmins': true,
                    'approveNewMembersOnlyAdmins': false,
                  },
                };

                Navigator.pop(context, newGroup);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Group "$name" created successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Create B2B Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
