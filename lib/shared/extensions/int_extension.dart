import 'package:flutter/material.dart';

/// Material icons that may be persisted as integer code points in the local
/// category table. Keeping explicit constant references here lets Flutter's
/// release icon tree-shaker know exactly which glyphs must remain bundled.
const List<IconData> _persistedMaterialIcons = <IconData>[
  Icons.beach_access_outlined,
  Icons.confirmation_number_outlined,
  Icons.handyman_outlined,
  Icons.home_outlined,
  Icons.local_gas_station_outlined,
  Icons.local_airport_outlined,
  Icons.airplane_ticket_outlined,
  Icons.monetization_on_outlined,
  Icons.person_outlined,
  Icons.card_giftcard_outlined,
  Icons.savings_outlined,
  Icons.videogame_asset_outlined,
  Icons.content_cut_outlined,
  Icons.tv_outlined,
  Icons.museum_outlined,
  Icons.music_note_outlined,
  Icons.cleaning_services_outlined,
  Icons.description_outlined,
  Icons.travel_explore_rounded,
  Icons.phone_android_outlined,
  Icons.photo_camera_outlined,
  Icons.sports_football_outlined,
  Icons.sports_bar_outlined,
  Icons.sports_esports_outlined,
  Icons.sports_basketball_outlined,
  Icons.smoking_rooms_outlined,
  Icons.cake_outlined,
  Icons.fitness_center_outlined,
  Icons.storefront_outlined,
  Icons.festival_rounded,
  Icons.festival_outlined,
  Icons.business_center_outlined,
  Icons.spa_outlined,
  Icons.child_friendly_outlined,
  Icons.build_outlined,
  Icons.call_outlined,
  Icons.directions_bus_outlined,
  Icons.checkroom_outlined,
  Icons.shopping_cart_outlined,
  Icons.medical_services_outlined,
  Icons.fastfood_outlined,
  Icons.school_outlined,
  Icons.more_outlined,
  Icons.casino_outlined,
  Icons.ssid_chart_outlined,
  Icons.account_balance_outlined,
  Icons.directions_car_filled_outlined,
  Icons.trending_up_outlined,
  Icons.currency_exchange_outlined,
  Icons.credit_score_outlined,
];

extension IntExtension on int {
  IconData parseIconData() {
    for (final IconData icon in _persistedMaterialIcons) {
      if (icon.codePoint == this) return icon;
    }

    // A database imported from an unknown/newer build may contain a code point
    // that this release does not know. Use a safe constant fallback rather than
    // constructing IconData dynamically, which would disable release tree-shaking.
    return Icons.help_outline;
  }
}
