import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state.dart';
import '../../booking/presentation/records_view_model.dart';
import 'account_view_model.dart';

class AccountTools extends ConsumerWidget {
  const AccountTools({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(accountProvider).asData?.value?.uid;
    if (uid == null) return const SizedBox.shrink();
    final addresses = ref.watch(
      recordsViewModelProvider((
        collection: 'customers/$uid/addresses',
        ownerField: null,
        ownerId: null,
        documentId: null,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Text(
          'Saved addresses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        addresses.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, s) => const Text('Unable to load addresses.'),
          data: (rows) => rows.isEmpty
              ? const Text('Add your home or work address.')
              : Column(
                  children: rows
                      .map(
                        (row) => ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(row.text('label')),
                          subtitle: Text(row.text('address')),
                        ),
                      )
                      .toList(),
                ),
        ),
        OutlinedButton.icon(
          onPressed: () => addAddress(context, ref),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add address'),
        ),
      ],
    );
  }

  Future<void> addAddress(BuildContext context, WidgetRef ref) async {
    final label = TextEditingController(), address = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Save an address'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: label,
                decoration: const InputDecoration(
                  labelText: 'Label, e.g. Home',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a label' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: address,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Full address'),
                validator: (v) => v == null || v.trim().length < 8
                    ? 'Enter the full address'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await ref
            .read(accountViewModelProvider.notifier)
            .saveAddress(label.text, address.text);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
    label.dispose();
    address.dispose();
  }
}
