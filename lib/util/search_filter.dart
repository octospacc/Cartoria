import 'package:flutter/material.dart';

import '../data/models.dart';

/// True when [post]'s creation timestamp falls within [range], inclusive
/// of both endpoints at day granularity. A null [range] matches every
/// post.
///
/// The end boundary is expanded to 23:59:59.999 of the chosen end day
/// so a range like "2025-01-01 to 2025-01-31" includes posts created
/// any time on Jan 31.
bool postMatchesDateRange(Post post, DateTimeRange? range) {
  if (range == null) return true;
  final created = post.createdAt.toLocal();
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(
      range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
  return !created.isBefore(start) && !created.isAfter(end);
}
