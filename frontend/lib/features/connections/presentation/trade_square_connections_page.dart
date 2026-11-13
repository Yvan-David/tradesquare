import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/mock_data/mock_connections.dart';
import '../../../core/mock_data/mock_businesses.dart';

class TradeSquareConnectionsPage extends StatefulWidget {
  const TradeSquareConnectionsPage({
    this.connections = const [],
    this.businesses = const [],
    this.userBusinessId,
    this.onNewConnection,
    this.onAccept,
    this.onDecline,
    this.onMessage,
    this.onConnect,
    this.onCall,
    super.key,
  });

  final List<TradeSquareMockConnection> connections;
  final List<TradeSquareMockBusiness> businesses;
  final String? userBusinessId;
  final VoidCallback? onNewConnection;
  final ValueChanged<TradeSquareMockConnection>? onAccept;
  final ValueChanged<TradeSquareMockConnection>? onDecline;
  final ValueChanged<TradeSquareMockConnection>? onMessage;
  final ValueChanged<TradeSquareMockBusiness>? onConnect;
  final ValueChanged<TradeSquareMockBusiness>? onCall;

  @override
  State<TradeSquareConnectionsPage> createState() =>
      _TradeSquareConnectionsPageState();
}

class _TradeSquareConnectionsPageState extends State<TradeSquareConnectionsPage> {
  String _filter = 'all';

  List<TradeSquareMockBusiness> get _peopleToMeet {
    final mine = widget.userBusinessId;
    final linked = <String>{
      if (mine != null && mine.isNotEmpty) mine,
      for (final connection in widget.connections) ...[
        connection.requestingBusinessId,
        connection.receivingBusinessId,
      ],
    };
    return widget.businesses
        .where((business) => business.id.isNotEmpty && !linked.contains(business.id))
        .toList();
  }

  List<TradeSquareMockConnection> get _filteredConnections {
    if (_filter == 'all') {
      return widget.connections;
    }
    if (_filter == 'declined') {
      return widget.connections
          .where((connection) =>
              connection.status == 'declined' ||
              connection.status == 'rejected')
          .toList();
    }
    return widget.connections
        .where((connection) => connection.status == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredConnections = _filteredConnections;
    final stats = _buildStats();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connections',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.connections.length} active relationships',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5B6474),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: widget.onNewConnection,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('New connection'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Active', value: '${stats['active']}', color: AppColors.primary),
                  _StatCard(label: 'Pending', value: '${stats['pending']}', color: const Color(0xFFF59E0B)),
                  _StatCard(label: 'Accepted', value: '${stats['accepted']}', color: const Color(0xFF16A34A)),
                  _StatCard(label: 'Blocked', value: '${stats['blocked']}', color: const Color(0xFFDC2626)),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'People to connect with',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'New members appear here so you can connect or call them.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B6474),
                    ),
              ),
              const SizedBox(height: 12),
              if (_peopleToMeet.isEmpty)
                const Text('No new members yet. Check back after someone registers.')
              else
                ..._peopleToMeet.map(
                  (business) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(
                      business: business,
                      onConnect: widget.onConnect,
                      onCall: widget.onCall,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', value: 'all', groupValue: _filter, onTap: _onFilterChanged),
                      _FilterChip(label: 'Pending', value: 'pending', groupValue: _filter, onTap: _onFilterChanged),
                      _FilterChip(label: 'Accepted', value: 'accepted', groupValue: _filter, onTap: _onFilterChanged),
                      _FilterChip(label: 'Declined', value: 'declined', groupValue: _filter, onTap: _onFilterChanged),
                      _FilterChip(label: 'Blocked', value: 'blocked', groupValue: _filter, onTap: _onFilterChanged),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (filteredConnections.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'No connections match this filter yet.',
                    style: TextStyle(fontSize: 16, color: AppColors.text),
                  ),
                )
              else
                ListView.separated(
                  itemCount: filteredConnections.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final connection = filteredConnections[index];
                    return _ConnectionCard(
                      connection: connection,
                      businesses: widget.businesses,
                      userBusinessId: widget.userBusinessId,
                      onAccept: widget.onAccept,
                      onDecline: widget.onDecline,
                      onMessage: widget.onMessage,
                      onCall: widget.onCall,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, int> _buildStats() {
    final stats = {
      'active': 0,
      'pending': 0,
      'accepted': 0,
      'declined': 0,
      'blocked': 0,
    };

    for (final connection in widget.connections) {
      switch (connection.status) {
        case 'pending':
          stats['pending'] = (stats['pending'] ?? 0) + 1;
          break;
        case 'accepted':
          stats['accepted'] = (stats['accepted'] ?? 0) + 1;
          break;
        case 'declined':
        case 'rejected':
          stats['declined'] = (stats['declined'] ?? 0) + 1;
          break;
        case 'blocked':
          stats['blocked'] = (stats['blocked'] ?? 0) + 1;
          break;
        default:
          break;
      }
    }

    stats['active'] = widget.connections.length;
    return stats;
  }

  void _onFilterChanged(String value) {
    setState(() => _filter = value);
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.business,
    this.onConnect,
    this.onCall,
  });

  final TradeSquareMockBusiness business;
  final ValueChanged<TradeSquareMockBusiness>? onConnect;
  final ValueChanged<TradeSquareMockBusiness>? onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${business.industry} · ${business.city}, ${business.country}',
                  style: const TextStyle(color: Color(0xFF59657A)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect == null ? null : () => onConnect!(business),
            child: const Text('Connect'),
          ),
          FilledButton.icon(
            onPressed: onCall == null ? null : () => onCall!(business),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.businesses,
    this.userBusinessId,
    this.onAccept,
    this.onDecline,
    this.onMessage,
    this.onCall,
  });

  final TradeSquareMockConnection connection;
  final List<TradeSquareMockBusiness> businesses;
  final String? userBusinessId;
  final ValueChanged<TradeSquareMockConnection>? onAccept;
  final ValueChanged<TradeSquareMockConnection>? onDecline;
  final ValueChanged<TradeSquareMockConnection>? onMessage;
  final ValueChanged<TradeSquareMockBusiness>? onCall;

  TradeSquareMockBusiness? _businessById(String id) {
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  TradeSquareMockBusiness? get _partnerBusiness {
    final mine = userBusinessId;
    if (mine != null && mine.isNotEmpty) {
      if (connection.receivingBusinessId == mine) {
        return _businessById(connection.requestingBusinessId);
      }
      if (connection.requestingBusinessId == mine) {
        return _businessById(connection.receivingBusinessId);
      }
    }
    return _businessById(connection.requestingBusinessId) ??
        _businessById(connection.receivingBusinessId);
  }

  bool get _isIncomingPending {
    final mine = userBusinessId;
    if (mine == null || mine.isEmpty) return false;
    return connection.status == 'pending' &&
        connection.receivingBusinessId == mine;
  }

  String get _displayStatus {
    if (connection.status == 'rejected') return 'declined';
    return connection.status;
  }

  Future<void> _respond(BuildContext context) async {
    final accept = onAccept;
    final decline = onDecline;
    if (accept == null && decline == null) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to request'),
        content: const Text('Accept or decline this connection request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('decline'),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('accept'),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (action == 'accept') accept?.call(connection);
    if (action == 'decline') decline?.call(connection);
  }

  @override
  Widget build(BuildContext context) {
    final partner = _partnerBusiness ?? TradeSquareMockBusiness(
      id: '',
      name: 'Trade partner',
      logoUrl: '',
      description: '',
      industry: '',
      category: '',
      country: '',
      province: '',
      city: '',
      address: '',
      email: '',
      phone: '',
      website: '',
      registrationNumber: '',
      registrationCertificateType: '',
      certificateSubmissionStatus: '',
      verificationStatus: TradeSquareMockVerificationStatus.notSubmitted,
      businessSize: '',
      yearEstablished: 2020,
      productsOffered: const [],
      productsNeeded: const [],
      businessInterests: const [],
      preferredMarkets: const [],
      ownerId: '',
      profileCompleteness: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final statusColor = switch (connection.status) {
      'accepted' => const Color(0xFF16A34A),
      'pending' => const Color(0xFFF59E0B),
      'declined' => const Color(0xFFDC2626),
      'blocked' => const Color(0xFF7C2D12),
      _ => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              partner.name.isNotEmpty ? partner.name.substring(0, 1).toUpperCase() : 'T',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        partner.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _displayStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${partner.city}, ${partner.country} · ${connection.relationshipType}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF59657A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(connection.requestDate),
                      style: const TextStyle(color: Color(0xFF59657A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (connection.introductoryMessage != null && connection.introductoryMessage!.isNotEmpty)
                  Text(
                    '“${connection.introductoryMessage}”',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF404B59),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionButton(label: 'View profile', onPressed: () {}),
                    if (_isIncomingPending)
                      _ActionButton(
                        label: 'Respond',
                        onPressed: () => _respond(context),
                      ),
                    _ActionButton(
                      label: 'Message',
                      onPressed: onMessage == null
                          ? null
                          : () => onMessage!(connection),
                    ),
                    _ActionButton(
                      label: 'Call',
                      onPressed: onCall == null || _partnerBusiness == null
                          ? null
                          : () => onCall!(_partnerBusiness!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][value.month - 1];
    return '$month ${value.day}, ${value.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5D6777),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : const Color(0xFF475467),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.border),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(label),
    );
  }
}
