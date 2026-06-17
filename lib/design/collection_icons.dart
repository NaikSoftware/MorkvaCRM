import 'package:flutter/material.dart';

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
  static const IconData fallback = Icons.style_outlined;

  /// The pickable catalog, in display order.
  static const List<CollectionIconOption> all = [
    CollectionIconOption('cards', Icons.style_outlined, 'Cards'),
    CollectionIconOption('grid', Icons.dashboard_customize_outlined, 'Grid'),
    CollectionIconOption('box', Icons.inventory_2_outlined, 'Inventory'),
    CollectionIconOption('truck', Icons.local_shipping_outlined, 'Shipping'),
    CollectionIconOption('cart', Icons.shopping_cart_outlined, 'Orders'),
    CollectionIconOption('bag', Icons.shopping_bag_outlined, 'Products'),
    CollectionIconOption('tag', Icons.sell_outlined, 'Pricing'),
    CollectionIconOption('people', Icons.groups_outlined, 'People'),
    CollectionIconOption('person', Icons.person_outline, 'Contact'),
    CollectionIconOption('business', Icons.apartment_outlined, 'Company'),
    CollectionIconOption('store', Icons.storefront_outlined, 'Store'),
    CollectionIconOption('money', Icons.payments_outlined, 'Finance'),
    CollectionIconOption('receipt', Icons.receipt_long_outlined, 'Invoices'),
    CollectionIconOption('calendar', Icons.event_outlined, 'Schedule'),
    CollectionIconOption('task', Icons.checklist_outlined, 'Tasks'),
    CollectionIconOption('folder', Icons.folder_outlined, 'Documents'),
    CollectionIconOption('note', Icons.sticky_note_2_outlined, 'Notes'),
    CollectionIconOption('star', Icons.star_outline, 'Favorites'),
    CollectionIconOption('flag', Icons.flag_outlined, 'Priorities'),
    CollectionIconOption('home', Icons.home_outlined, 'Properties'),
    CollectionIconOption('car', Icons.directions_car_outlined, 'Vehicles'),
    CollectionIconOption('build', Icons.build_outlined, 'Services'),
    CollectionIconOption('pets', Icons.pets_outlined, 'Pets'),
    CollectionIconOption('restaurant', Icons.restaurant_outlined, 'Menu'),
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
