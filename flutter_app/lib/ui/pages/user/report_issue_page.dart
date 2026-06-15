import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  String _selectedCategory = 'Payment Issue';
  final _descController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _error;

  final List<String> _categories = ['Payment Issue', 'Order Problem', 'App Bug', 'Merchant Behavior', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await supportService.loadIssues();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submit() async {
    if (_descController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await supportService.reportIssue(_selectedCategory, _descController.text.trim());
      if (!mounted) return;
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket submitted successfully!')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit ticket. $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ink),
        title: const Text('Report an Issue', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Create a Ticket', 'Submit your problem'),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Describe your issue',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(_isSubmitting ? 'Submitting...' : 'Submit Ticket', Icons.send, _isSubmitting ? () {} : _submit),
            const SizedBox(height: 48),
            const SectionHeader('Active Tickets', 'Track your requests'),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text('Could not load tickets. $_error', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _loadTickets, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
            _buildTicketList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return InkWell(
          onTap: () => setState(() => _selectedCategory = cat),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? primary : muted.withOpacity(0.2)),
            ),
            child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : ink, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTicketList() {
    return ValueListenableBuilder<List<SupportIssue>>(
      valueListenable: supportService.issues,
      builder: (context, issues, _) {
        if (issues.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.assignment_outlined, size: 48, color: muted.withOpacity(0.2)),
                const SizedBox(height: 8),
                const Text('No active tickets', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return Column(
          children: issues.reversed.map((issue) => _TicketItem(issue: issue)).toList(),
        );
      },
    );
  }
}

class _TicketItem extends StatelessWidget {
  const _TicketItem({required this.issue});
  final SupportIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: shadowSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.id,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(status: issue.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(issue.category, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(issue.description, style: const TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final IssueStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case IssueStatus.pending: color = Colors.orange; label = 'Pending'; break;
      case IssueStatus.inProgress: color = primary; label = 'In Progress'; break;
      case IssueStatus.resolved: color = success; label = 'Resolved'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}
