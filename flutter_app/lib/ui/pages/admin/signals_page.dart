import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminSignalsPage extends StatefulWidget {
  const AdminSignalsPage({super.key});

  @override
  State<AdminSignalsPage> createState() => _AdminSignalsPageState();
}

class _AdminSignalsPageState extends State<AdminSignalsPage> {
  String _audience = 'all';
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _history = const [];

  final List<Map<String, dynamic>> _audienceOptions = const [
    {'value': 'all', 'label': 'All', 'icon': Icons.public},
    {'value': 'users', 'label': 'Users', 'icon': Icons.person_outline},
    {'value': 'sellers', 'label': 'Sellers', 'icon': Icons.storefront_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSignals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await apiClient.getJson('/api/admin/signals');
      if (!mounted) return;
      setState(() {
        _history = (data['signals'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendSignal() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and body are both required to broadcast a signal.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await apiClient.postJson('/api/admin/signals', {
        'audience': _audience,
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      await _loadSignals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signal broadcast stored and notifications queued.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not broadcast signal. $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteSignal(Map<String, dynamic> signal) async {
    final signalId = signal['id']?.toString();
    if (signalId == null || signalId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete signal?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('This removes the signal from admin history. Already delivered notifications stay on user devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await apiClient.deleteJson('/api/admin/signals/$signalId');
      if (!mounted) return;
      setState(() {
        _history = _history
            .where((item) => item['id']?.toString() != signalId)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signal deleted from history.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete signal. $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _formatTime(Object? value) {
    final dt = DateTime.tryParse(value?.toString() ?? '');
    if (dt == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: [
        const PageTitle('Signals Control', 'Broadcast backend notifications to users and sellers.'),
        const SizedBox(height: 32),
        const Kicker('TARGET AUDIENCE'),
        const SizedBox(height: 12),
        _buildAudienceTabs(),
        const SizedBox(height: 28),
        const Kicker('COMPOSE SIGNAL'),
        const SizedBox(height: 12),
        _buildComposer(),
        const SizedBox(height: 32),
        const Kicker('SIGNAL HISTORY'),
        const SizedBox(height: 12),
        if (_error != null) _buildErrorCard(),
        if (_isLoading) const LinearProgressIndicator(),
        if (!_isLoading && _history.isEmpty)
          _buildEmptyCard('No backend signals broadcast yet.')
        else
          ..._history.map(_buildHistoryCard),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildAudienceTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: _audienceOptions.map((opt) {
          final value = opt['value'] as String;
          final isSelected = _audience == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _audience = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(opt['icon'] as IconData, color: isSelected ? Colors.white : muted, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isSelected ? Colors.white : muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
        border: Border.all(color: muted.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.send, size: 14, color: primary),
                const SizedBox(width: 6),
                Text(
                  'Broadcasting to: ${_audienceLabel(_audience)}',
                  style: const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Notification Title',
              prefixIcon: const Icon(Icons.title, color: muted),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Notification Body',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 72),
                child: Icon(Icons.message_outlined, color: muted),
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendSignal,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.campaign, size: 20),
              label: Text(
                _sending ? 'Broadcasting...' : 'Broadcast Signal Now',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: primary.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> signal) {
    final audience = signal['audience']?.toString() ?? 'all';
    final audienceColor = switch (audience) {
      'users' => Colors.teal,
      'sellers' => Colors.deepOrange,
      _ => primary,
    };
    final audienceIcon = switch (audience) {
      'users' => Icons.person_outline,
      'sellers' => Icons.storefront_outlined,
      _ => Icons.public,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: muted.withOpacity(0.1)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  signal['title']?.toString() ?? 'Signal',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(signal['createdAt']),
                style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              PopupMenuButton<String>(
                tooltip: 'Signal actions',
                icon: const Icon(Icons.more_vert_rounded, color: muted, size: 20),
                onSelected: (value) {
                  if (value == 'delete') _deleteSignal(signal);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            signal['body']?.toString() ?? '',
            style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(audienceIcon, size: 13, color: audienceColor),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: audienceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sent to ${_audienceLabel(audience)}',
                  style: TextStyle(color: audienceColor, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${signal['recipientCount'] ?? 0} queued',
                  style: const TextStyle(color: success, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text('Could not load signals. $_error')),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowSm,
      ),
      child: Text(text, style: const TextStyle(color: muted, fontWeight: FontWeight.w800)),
    );
  }

  String _audienceLabel(String value) {
    return switch (value) {
      'users' => 'Users',
      'sellers' => 'Sellers',
      _ => 'All Users & Sellers',
    };
  }
}
