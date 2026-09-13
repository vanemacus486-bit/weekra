import 'package:flutter/material.dart';

/// A stable category identity and its current display color.
///
/// Weekra's first releases stored only a color on each event. The IDs below
/// preserve those six choices without inventing meanings for user data. The
/// neutral labels shown in the UI can be replaced once their intended names
/// are confirmed; event membership will remain intact because it uses [id].
class EventCategory {
  const EventCategory({required this.id, required this.color});

  final String id;
  final Color color;
}

abstract final class EventCategories {
  static const uncategorizedId = 'uncategorized';

  static const uncategorized = EventCategory(
    id: uncategorizedId,
    color: Color(0xFF7C8188),
  );

  static const values = <EventCategory>[
    EventCategory(id: 'category-1', color: Color(0xFFF1776C)),
    EventCategory(id: 'category-2', color: Color(0xFF70B8AF)),
    EventCategory(id: 'category-3', color: Color(0xFF7F9DD4)),
    EventCategory(id: 'category-4', color: Color(0xFFC6A15B)),
    EventCategory(id: 'category-5', color: Color(0xFFB7799E)),
    EventCategory(id: 'category-6', color: Color(0xFF72A57C)),
  ];

  static EventCategory? byId(String? id) {
    if (id == uncategorizedId) {
      return uncategorized;
    }
    for (final category in values) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  static String idForLegacyColor(Color? color) {
    if (color != null) {
      for (final category in values) {
        if (category.color.toARGB32() == color.toARGB32()) {
          return category.id;
        }
      }
    }
    return uncategorizedId;
  }

  static Color colorFor(String? id, {Color? legacyColor}) {
    final category = byId(id);
    if (category == null || category.id == uncategorizedId) {
      return legacyColor ?? uncategorized.color;
    }
    return category.color;
  }
}
