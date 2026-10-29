import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state.dart';
import '../../technician/presentation/media_view_model.dart';
import '../../booking/presentation/records_view_model.dart';

// Query active service documents without string/bool coercion; filter the small
// bounded catalog in the view. Catalog pricing remains rule-enforced on booking.
class CatalogView extends ConsumerStatefulWidget {
  const CatalogView({super.key});
  @override
  ConsumerState<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends ConsumerState<CatalogView> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final result = ref.watch(
      recordsViewModelProvider((
        collection: 'service_categories',
        ownerField: null,
        ownerId: null,
        documentId: null,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Find a service',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('What can we help you fix today?'),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search all services',
          ),
        ),
        const SizedBox(height: 18),
        result.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Column(
            children: [
              const Text('Could not load services.'),
              TextButton(
                onPressed: () => ref.invalidate(recordsViewModelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (rows) {
            final items = rows
                .where(
                  (row) =>
                      row.values['active'] == true &&
                      row.text('name').toLowerCase().contains(search),
                )
                .toList();
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No matching services found.'),
              );
            }
            return LayoutBuilder(
              builder: (_, b) => Wrap(
                spacing: 12,
                runSpacing: 16,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: (b.maxWidth - 24) / 3,
                        child: InkWell(
                          onTap: () {
                            ref.read(flowProvider.notifier).booking('');
                            ref.read(mediaViewModelProvider.notifier).clear();
                            ref
                                .read(flowProvider.notifier)
                                .field('categoryId', item.id);
                            ref
                                .read(flowProvider.notifier)
                                .field('categoryName', item.text('name'));
                            ref
                                .read(flowProvider.notifier)
                                .field('visitFee', item.text('visitFee'));
                            ref
                                .read(flowProvider.notifier)
                                .field('technicianId', '');
                            context.push('/screen/10');
                          },
                          child: Column(
                            children: [
                              Container(
                                height: 78,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDF5FB),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Center(
                                  child: Icon(
                                    iconForCategory(item.id),
                                    color: const Color(0xFF319DC3),
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.text('name'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'ETB ${item.text('visitFee')} visit',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

IconData iconForCategory(String id) => switch (id) {
  'refrigerator' => Icons.kitchen_outlined,
  'electrical' => Icons.lightbulb_outline,
  'ac' => Icons.ac_unit,
  'satellite' => Icons.satellite_alt,
  'plumbing' => Icons.plumbing,
  'tv' => Icons.tv,
  'washing' => Icons.local_laundry_service_outlined,
  'cctv' => Icons.videocam_outlined,
  'water-pump' => Icons.water_drop_outlined,
  'computer' => Icons.computer,
  'microwave' => Icons.microwave_outlined,
  _ => Icons.home_repair_service_outlined,
};
