abstract class PageCursor {}

class Page<T> {
  /// the items in this page
  final List<T> items;

  /// a value that's used to fetch the next page.
  ///
  /// this is a user defined value. See [IntPageCursor] for an example
  final PageCursor? cursor;

  /// whether this page is the last page in the list
  ///
  /// should never change from false to true for a single page, i.e. when
  /// recieving updates.
  ///
  /// it's however permitted to change it from true to false
  final bool isLastPage;

  Page(this.items, this.cursor, this.isLastPage);

  Page.initial()
      : items = const [],
        cursor = null,
        isLastPage = false;
}

class IntPageCursor implements PageCursor {
  final int next;

  IntPageCursor(this.next);
}
