import 'package:flutter_test/flutter_test.dart';

import 'package:live_paginated_list/live_paginated_list.dart';

void main() {
  test('can create a controller', () {
    expect(
        PaginationController<ListState<int>, int>((cursor) => null, true)
            is PaginationController<ListState<int>, int>,
        true);
  });
}
