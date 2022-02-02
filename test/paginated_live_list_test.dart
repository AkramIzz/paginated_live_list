import 'package:paginated_live_list/paginated_live_list.dart';

class TestPaginationController extends PaginationController<int> {
  @override
  Page<int> adjustCursor(Page<int> page, Page<int>? nextPage) {
    throw UnimplementedError();
  }

  @override
  Page<int> createAdjustmentPage(Page<int> page, Page<int> oldPage) {
    throw UnimplementedError();
  }

  @override
  Stream<Page<int>> onLoadPage(PageCursor? cursor) {
    throw UnimplementedError();
  }

  @override
  int compareTo(Page<int> page, Page<int> other) {
    throw UnimplementedError();
  }
}

void main() {}
