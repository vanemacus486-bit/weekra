import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/calendar/domain/event_category_suggestion.dart';

void main() {
  test('suggests an unambiguous category from matching local history', () {
    final suggestion = suggestCategoryForTitle('  Study  ', [
      (title: 'study', categoryId: 'category-2'),
      (title: 'Study', categoryId: 'category-2'),
    ]);

    expect(suggestion, 'category-2');
  });

  test('does not guess when matching local history conflicts', () {
    final suggestion = suggestCategoryForTitle('Study', [
      (title: 'Study', categoryId: 'category-2'),
      (title: 'Study', categoryId: 'category-4'),
    ]);

    expect(suggestion, isNull);
  });
}
