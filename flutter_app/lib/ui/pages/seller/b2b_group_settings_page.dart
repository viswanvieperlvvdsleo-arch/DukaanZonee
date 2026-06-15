import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class B2BGroupSettingsPage extends StatefulWidget {
  const B2BGroupSettingsPage({super.key, required this.groupData});

  final Map<String, dynamic> groupData;

  @override
  State<B2BGroupSettingsPage> createState() => _B2BGroupSettingsPageState();
}

class _B2BGroupSettingsPageState extends State<B2BGroupSettingsPage> {
  late Map<String, dynamic> _permissions;

  @override
  void initState() {
    super.initState();
    // Fetch or initialize permissions map safely
    widget.groupData['permissions'] ??= {
      'sendMessagesOnlyAdmins': false,
      'editSettingsOnlyAdmins': true,
      'approveNewMembersOnlyAdmins': false,
    };
    _permissions = widget.groupData['permissions'];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color lightGray = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color border = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final Color primaryGreen = const Color(0xFF10B981);

    final membersList = widget.groupData['members'] as List<dynamic>? ?? [];

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
          'Group Settings',
          style: TextStyle(fontWeight: FontWeight.w900, color: textPrimary, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADMIN PERMISSIONS',
            style: TextStyle(color: lightGray, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // 1. Switches Card
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Send Messages',
                  subtitle: 'Lock chat and restrict messaging rights to administrators.',
                  value: _permissions['sendMessagesOnlyAdmins'] ?? false,
                  activeColor: primaryGreen,
                  textPrimary: textPrimary,
                  lightGray: lightGray,
                  onChanged: (bool val) {
                    setState(() {
                      _permissions['sendMessagesOnlyAdmins'] = val;
                    });
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSwitchTile(
                  icon: Icons.edit_attributes_rounded,
                  title: 'Edit Group Settings',
                  subtitle: 'Restrict edits to name, agenda, and privacy controls.',
                  value: _permissions['editSettingsOnlyAdmins'] ?? true,
                  activeColor: primaryGreen,
                  textPrimary: textPrimary,
                  lightGray: lightGray,
                  onChanged: (bool val) {
                    setState(() {
                      _permissions['editSettingsOnlyAdmins'] = val;
                    });
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSwitchTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Approve New Participants',
                  subtitle: 'Admins must verify all wholesale merchant requests.',
                  value: _permissions['approveNewMembersOnlyAdmins'] ?? false,
                  activeColor: primaryGreen,
                  textPrimary: textPrimary,
                  lightGray: lightGray,
                  onChanged: (bool val) {
                    setState(() {
                      _permissions['approveNewMembersOnlyAdmins'] = val;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. Manage Admins Title
          Text(
            'MANAGE GROUP ROLES',
            style: TextStyle(color: lightGray, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // 3. Member Administration card
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                if (membersList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Text('No group members.', style: TextStyle(color: lightGray)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: membersList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final member = membersList[index];
                      final bool isAdmin = member['isAdmin'] == true;
                      final bool isMe = member['name'] == 'You';
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: primaryGreen.withOpacity(0.12),
                          child: Text(
                            member['name']?[0] ?? 'M',
                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 12),
                          ),
                        ),
                        title: Text(
                          member['name'],
                          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          isAdmin ? 'Group Administrator' : 'Member',
                          style: TextStyle(color: lightGray, fontSize: 11),
                        ),
                        trailing: isMe
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Owner',
                                  style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              )
                            : Switch(
                                value: isAdmin,
                                activeColor: primaryGreen,
                                onChanged: (bool val) {
                                  setState(() {
                                    member['isAdmin'] = val;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${member['name']} role updated to ${val ? 'Admin' : 'Member'}.'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      )),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required Color textPrimary,
    required Color lightGray,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SwitchListTile(
        activeColor: activeColor,
        title: Row(
          children: [
            Icon(icon, color: lightGray, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 34.0, top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(color: lightGray.withOpacity(0.8), fontSize: 11.5),
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
