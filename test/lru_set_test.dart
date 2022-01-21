import 'package:flutter_test/flutter_test.dart';

import 'package:paginated_live_list/src/helpers/lru_set.dart';

void main() {
  test('can add element to an empty LruSet', () {
    final lruSet = LruSet<int>(5);
    expect(lruSet.put(1), null);
    expect(lruSet.length, 1);
  });
  test('can test whether an element is in the LruSet or not', () {
    final lruSet = LruSet<int>(5)
      ..put(1)
      ..put(2)
      ..put(3);
    expect(lruSet.contains(1), true);
    expect(lruSet.contains(4), false);
  });
  test(
      'can add elements within the capacity of the LruSet without removing other elements',
      () {
    final lruSet = LruSet<int>(3);
    lruSet.put(1);
    expect(lruSet.length, 1);
    lruSet.put(2);
    expect(lruSet.length, 2);
    lruSet.put(3);
    expect(lruSet.length, 3);
  });
  test('adding an element to a full LruSet removes an item and returns it', () {
    final lruSet = LruSet<int>(3)
      ..put(1)
      ..put(2)
      ..put(3);
    expect(lruSet.length, 3);
    expect(lruSet.put(4), 1);
    expect(lruSet.length, 3);
  });
  test('adding an item for a second time does not affect the set', () {
    final lruSet = LruSet<int>(3);
    lruSet
      ..put(1)
      ..put(1);
    expect(lruSet.length, 1);
  });
  test('adding an already existing item updates it in the LRU list', () {
    final lruSet = LruSet<int>(3)
      ..put(1)
      ..put(2)
      ..put(3);
    lruSet.put(1);
    expect(lruSet.put(4), 2);
    expect(lruSet.put(5), 3);
    expect(lruSet.put(6), 1);
  });
}
