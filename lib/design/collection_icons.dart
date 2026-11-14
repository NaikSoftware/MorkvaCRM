import 'package:flutter/material.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// One entry in the curated collection-icon catalog: a stable [key] (what gets
/// persisted on `Collection.icon`), the [icon] it renders to, and a short
/// [label] for accessibility and picker tooltips.
@immutable
class CollectionIconOption {
  const CollectionIconOption(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

/// The curated set of collection icons.
///
/// We persist a small string [CollectionIconOption.key] rather than a raw
/// [IconData] so collections serialize cleanly to Firestore and survive icon
/// font changes. The catalog is intentionally small and on-brand; new entries
/// can be appended freely (keys must never be reused for a different glyph).
/// Every glyph is a `const` [IconData] so the icon tree-shaker still works.
abstract final class CollectionIcons {
  /// Rendered when a collection has no icon, or an unknown/retired key.
  static const IconData fallback = MorkvaIcons.cards;

  /// The pickable catalog, in display order.
  static const List<CollectionIconOption> all = [
    CollectionIconOption('cards', MorkvaIcons.cards, 'Cards'),
    CollectionIconOption('grid', MorkvaIcons.dashboard, 'Grid'),
    CollectionIconOption('box', MorkvaIcons.inventory, 'Inventory'),
    CollectionIconOption('truck', MorkvaIcons.shipping, 'Shipping'),
    CollectionIconOption('cart', MorkvaIcons.cart, 'Orders'),
    CollectionIconOption('bag', MorkvaIcons.bag, 'Products'),
    CollectionIconOption('tag', MorkvaIcons.sell, 'Pricing'),
    CollectionIconOption('people', MorkvaIcons.groups, 'People'),
    CollectionIconOption('person', MorkvaIcons.person, 'Contact'),
    CollectionIconOption('business', MorkvaIcons.apartment, 'Company'),
    CollectionIconOption('store', MorkvaIcons.store, 'Store'),
    CollectionIconOption('money', MorkvaIcons.payments, 'Finance'),
    CollectionIconOption('receipt', MorkvaIcons.receipt, 'Invoices'),
    CollectionIconOption('calendar', MorkvaIcons.event, 'Schedule'),
    CollectionIconOption('task', MorkvaIcons.checklist, 'Tasks'),
    CollectionIconOption('folder', MorkvaIcons.folder, 'Documents'),
    CollectionIconOption('note', MorkvaIcons.stickyNote, 'Notes'),
    CollectionIconOption('star', MorkvaIcons.star, 'Favorites'),
    CollectionIconOption('flag', MorkvaIcons.flag, 'Priorities'),
    CollectionIconOption('home', MorkvaIcons.home, 'Properties'),
    CollectionIconOption('car', MorkvaIcons.car, 'Vehicles'),
    CollectionIconOption('build', MorkvaIcons.build, 'Services'),
    CollectionIconOption('pets', MorkvaIcons.pets, 'Pets'),
    CollectionIconOption('restaurant', MorkvaIcons.restaurant, 'Menu'),
  ];

  /// The [IconData] for [key], or [fallback] when [key] is null or not in the
  /// catalog (a retired key on an old document degrades gracefully).
  static IconData byKey(String? key) {
    if (key == null) return fallback;
    for (final option in all) {
      if (option.key == key) return option.icon;
    }
    return fallback;
  }
}
