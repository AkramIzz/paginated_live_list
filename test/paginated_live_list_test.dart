import 'package:flutter_test/flutter_test.dart';

import 'package:paginated_live_list/paginated_live_list.dart';

void main() {
  test('can create a controller', () {
    expect(
        PaginationController<int>(
                (cursor) => Stream.value(Page.initial()), true)
            is PaginationController<int>,
        true);
  });
}
