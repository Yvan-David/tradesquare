import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/api/catalog_store.dart';
import '../../../core/mock_data/mock_businesses.dart';
import '../../../core/mock_data/mock_buying_requests.dart';

class TradeSquareOpportunitiesPage extends StatelessWidget {
  const TradeSquareOpportunitiesPage({
    required this.buyerBusinessId,
    this.onCreated,
    super.key,
  });

  final String buyerBusinessId;
  final VoidCallback? onCreated;

  @override
  Widget build(BuildContext context) {
    final requests = CatalogStore.instance.buyingRequests;
    final businesses = {
      for (final business in tradeSquareMockBusinesses) business.id: business,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: buyerBusinessId.isEmpty
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Complete business onboarding before creating requests.',
                    ),
                  ),
                );
              }
            : () => _openCreateDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Create request'),
      ),
      body: SafeArea(
        child: requests.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No buying requests yet. Create one to attract suppliers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.text),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final buyer = businesses[request.buyerBusinessId];
                  return _RequestCard(request: request, buyerName: buyer?.name);
                },
              ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateRequestDialog(buyerBusinessId: buyerBusinessId),
    );
    if (created == true) onCreated?.call();
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.buyerName,
  });

  final TradeSquareMockBuyingRequest request;
  final String? buyerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.productOrService,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            buyerName ?? 'Unknown buyer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF59657A),
                ),
          ),
          if (request.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(request.description),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipLabel(text: request.category),
              _ChipLabel(text: '${request.requiredQuantity} ${request.unit}'),
              _ChipLabel(text: request.urgency),
              if (request.deliveryDestination.isNotEmpty)
                _ChipLabel(text: request.deliveryDestination),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CreateRequestDialog extends StatefulWidget {
  const _CreateRequestDialog({required this.buyerBusinessId});

  final String buyerBusinessId;

  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final _productController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'unit');
  final _destinationController = TextEditingController();
  String _urgency = 'Medium';
  bool _submitting = false;

  @override
  void dispose() {
    _productController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final product = _productController.text.trim();
    if (product.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await CatalogStore.instance.createBuyingRequest(
        buyerBusinessId: widget.buyerBusinessId,
        productOrService: product,
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        requiredQuantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        unit: _unitController.text.trim(),
        deliveryDestination: _destinationController.text.trim(),
        urgency: _urgency,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create request: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create buying request'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _productController,
                decoration: const InputDecoration(labelText: 'Product / service'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
              DropdownButtonFormField<String>(
                value: _urgency,
                decoration: const InputDecoration(labelText: 'Urgency'),
                items: const ['Low', 'Medium', 'High']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _urgency = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Publish'),
        ),
      ],
    );
  }
}
