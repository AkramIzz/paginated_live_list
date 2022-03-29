import 'package:paginated_live_list/paginated_live_list.dart';

class TestPaginationController extends PaginationController<int> {
  @override
  Stream<Page<int>> onLoadPage(PageCursor? cursor) {
    throw UnimplementedError();
  }

  @override
  int comparePagesOrder(Page<int> page, Page<int> other) {
    throw UnimplementedError();
  }

  @override
  Page<int> updateCursorOfAdjustedPage(Page<int> page) {
    throw UnimplementedError();
  }
}

void main() {}
