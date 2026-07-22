import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class CompanyResourcesScreen extends StatelessWidget {
  const CompanyResourcesScreen(
      {super.key,
      required this.title,
      required this.kind,
      required this.items});
  final String title, kind;
  final List<Map<String, dynamic>> items;

  IconData get resourceIcon => kind == 'product'
      ? Icons.inventory_2_outlined
      : kind == 'free'
          ? Icons.redeem_rounded
          : Icons.add_shopping_cart_rounded;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: items.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(resourceIcon, size: 52, color: Colors.black26),
                const SizedBox(height: 10),
                Text('No $title added yet.',
                    style: const TextStyle(
                        color: Colors.black45, fontWeight: FontWeight.w700)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                itemCount: items.length,
                itemExtent: items.length > 7 ? 98 : null,
                itemBuilder: (_, i) => resourceCard(items[i])),
      );

  Widget resourceCard(Map<String, dynamic> item) {
    final images =
        item['images'] is List ? List.from(item['images']) : const [];
    final image = resolveApiAssetUrl(kind == 'product'
        ? (images.isEmpty ? '' : images.first.toString())
        : item['imageUrl']);
    final qty = kind == 'free' ? item['entitledQty'] : item['qty'];
    final price =
        kind == 'product' ? item['price'] : item['unitPrice'] ?? item['price'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(13)),
            child: image.isNotEmpty
                ? Image.network(image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(resourceIcon, color: AppColors.green))
                : Icon(resourceIcon, color: AppColors.green),
          ),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(item['name']?.toString() ?? 'Item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                if (item['category']?.toString().isNotEmpty == true)
                  Text(item['category'].toString(),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black45)),
                const SizedBox(height: 4),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  if (qty != null)
                    tag(kind == 'free' ? 'Entitled: $qty' : 'Qty: $qty'),
                  if (kind == 'free') tag('Taken: ${item['claimedQty'] ?? 0}'),
                  if (kind == 'free') tag('Left: ${item['remainingQty'] ?? 0}'),
                  if (price != null && num.tryParse(price.toString()) != 0)
                    tag('INR $price'),
                  if (item['paymentStatus']?.toString().isNotEmpty == true)
                    tag(item['paymentStatus'].toString()),
                ]),
              ])),
        ]),
      ),
    );
  }

  Widget tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
      );
}
