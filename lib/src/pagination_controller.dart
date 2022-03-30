import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'page_cursor.dart';
import 'helpers/result.dart';
import 'helpers/as_unicast_stream.dart';
import 'helpers/behavior_stream.dart';
import 'helpers/stream_error_wrapper.dart';

enum PageStatus {
  /// The page is being loaded
  ///
  /// Since a new page won't be added to the [ListState.pagesStates] until it's
  /// loaded, this state also indicates that the loading happended after
  /// an error occured and a retry was initiated
  loading,

  /// The page has been loaded
  loaded,

  /// An error occured while either loading the page or listening to updates.
  /// if the error occured while listening to updates, the last
  /// updated page is still accessible through [PageState.page]
  error,
}

enum ListStatus {
  /// The initial state where there's no pages and no page is being loaded.
  initial,

  /// A new page is being loaded.
  ///
  /// The new page won't be added to [PageState.pagesStates] until it's loaded
  loading,

  /// All pages with errors are being loaded
  reloading,

  /// The latest page has been loaded.
  /// This status doesn't mean there's no errors in all the pages. Only that the
  /// initial loading of all pages has completed successfully. Errors from the
  /// updating stream aren't reflected in the ListStatus
  loaded,

  /// An error occured while loading a new page.
  /// If an error occured while listening to updates, the
  /// [ListState.status] doesn't change to error.
  error,

  /// The list has reached the last page and there's no more pages to load.
  ///
  /// It's the user's job to signal the end of the list by returning a page where
  /// [Page.isLastPage] is true.
  ///
  /// It's possible for a list to go from [ListStatus.end] to
  /// [ListStatus.loaded], e.g. if new items were added to the list
  end,
}

/// The container for a page, it's status and the error that occured while
/// loading or updating it if any
class PageState<T> {
  /// The current status of loading this page.
  final PageStatus status;

  /// The last loaded page content.
  ///
  /// This value is never null after the initial loading.
  /// If an error occurs on the updates stream of this page, this value
  /// will hold to the last successful update.
  final Page<T> page;

  /// the error this page had if any
  final Object? error;

  /// used to reference a page within [ListState.pagesStates]
  final PageKey key;

  PageState(this.key, this.status, this.page, this.error);
}

/// Used to reference a page within [ListState.pagesStates]
///
/// Each page maintains a unique instance of this class. When updating a page
/// it's key is used to identify where it resides in the pages list.
///
/// Due to adjustments when a cursor change, a page's index in
/// [ListState.pagesStates] can change, thus it can't be used to identify the
/// page that needs to be updated.
class PageKey {
  int? _debugValue;

  PageKey([this._debugValue]) {
    _debugValue ??= _id++;
  }

  @override
  String toString() {
    return '$runtimeType($_debugValue)';
  }

  static var _id = 0;
}

class ListState<T> {
  /// the overall status of the paginated list.
  ///
  /// in order, the rule for this status is
  /// 1. [ListStatus.reloading] if pages with errors are being loaded
  /// 2. [ListStatus.error] if there's an error at a newly loaded page
  /// 3. [ListStatus.loading] if the last page is loading
  /// 4. [ListStatus.end] if all pages are loaded and there's no more pages
  /// 5. [ListStatus.loaded] if all pages are loaded
  final ListStatus status;

  /// the last recieved error
  final Object? error;

  /// A list of all the pages with their states
  ///
  /// If a new page is being loaded, i.e. the [ListState.status] is
  /// [ListStatus.loading], this new page won't be in the list until it's loaded
  final List<PageState<T>> pagesStates;

  /// An expanded list of the content of all the pages
  final List<T> items;

  ListState(this.status, this.pagesStates, this.error)
      : items =
            pagesStates.map((ps) => ps.page.items).expand((it) => it).toList();

  ListState.initial()
      : status = ListStatus.initial,
        pagesStates = const [],
        items = const [],
        error = null;

  ListState<T> copyWithStatus(ListStatus status) {
    return ListState(status, this.pagesStates, this.error);
  }

  bool pageStatusExists(PageStatus status) {
    return pagesStates.firstWhereOrNull((ps) => ps.status == status) != null;
  }

  PageState<T> pageStateOfKey(PageKey key) {
    return pagesStates.firstWhere((p) => p.key == key);
  }
}

/// The manager class for the live list.
/// It manages the pages subscriptions, the state of the list and loading pages
/// and retrying pages with errors
///
/// It provides a `BehaviorSubject` interface which is a stream that caches the
/// latest event and when subscribed to emits the cached event to the listener
abstract class PaginationController<T> extends BehaviorStream<ListState<T>> {
  /// a callback for loading new pages.
  /// The cursor of the page preceding the requested page is passed or null if
  /// the requested page is the first page.
  ///
  /// There's no mandate on whether the stream should close after an error.
  Stream<Page<T>> onLoadPage(covariant PageCursor? cursor);

  PaginationController() : _states = StreamController<ListState<T>>.broadcast();

  StreamController<ListState<T>> _states;

  /// An ordered list of the pages updates streams subscriptions
  final subscriptions = <PageKey, StreamSubscription<Result<Page<T>>>>{};

  /// The current and last emitted list state.
  ///
  /// Refrain from using this value and listen to the stream if possible as
  /// there's no gaurantee that the event parameter of a subscription listener
  /// is the last emitted value when invoked.
  ListState<T> current = ListState.initial();

  /// Loads the next page. Typically called by the [PaginatedLiveList] widget
  void loadNextPage() {
    _emit(ListState(ListStatus.loading, current.pagesStates, current.error));
    final cursor = current.pagesStates.lastOrNull?.page.cursor;
    _loadPageAndSubscribe(cursor, null, subscriptions.length);
  }

  /// Reloads the pages that had an error while loading the initial page or
  /// on subsequent updates.
  void reloadErroredPages() {
    final pagesStatuses = List.of(current.pagesStates, growable: false);

    for (int i = 0; i < current.pagesStates.length; ++i) {
      if (pagesStatuses[i].status != PageStatus.error) continue;
      pagesStatuses[i] = _reloadPage(i, pagesStatuses[i]);
    }
    _emit(ListState(ListStatus.reloading, pagesStatuses, current.error));

    late final StreamSubscription<ListState<T>> sub;
    // Listen to the states stream and emit a new state when all pages are done
    // reloading.
    // None of the pages reloading will result in a new [ListState.status]
    // since they are all updates to existing pages.
    // Thus we need to change the `ListState.status` after all the pages are
    // done loading.
    //
    // see _updatePage for a clarification on how [ListState.status] is updated
    sub = _states.stream.listen((state) {
      final isLoading = state.pageStatusExists(PageStatus.loading);
      if (!isLoading) {
        sub.cancel();
        // Update status according to last page.
        if (state.pagesStates.last.status == PageStatus.error) {
          _emit(current.copyWithStatus(ListStatus.error));
        } else {
          final status = current.pagesStates.last.page.isLastPage
              ? ListStatus.end
              : ListStatus.loaded;
          _emit(current.copyWithStatus(status));
        }
      }
    });
  }

  PageState<T> _reloadPage(int index, PageState<T> pageState) {
    subscriptions[pageState.key]!.cancel();

    final cursor =
        index == 0 ? null : current.pagesStates[index - 1].page.cursor;
    _loadPageAndSubscribe(cursor, pageState.key, index);

    return PageState(
      pageState.key,
      PageStatus.loading,
      pageState.page,
      pageState.error,
    );
  }

  void _loadPageAndSubscribe(PageCursor? cursor, PageKey? key, int pageIndex) {
    key ??= PageKey();
    final listStream = orErrorWrapper.call(
      () => asUnicastStream(create: () => onLoadPage(cursor)),
    );
    subscriptions[key] = listStream.listen((res) {
      _emit(_updatePage(key!, res));
    });
  }

  /// Returns a new ListState given an update to a page
  ///
  /// Ignoring [ListStatus.reloading], the [ListState.status] is resolved as:
  /// - if the page result is a value:
  ///   - if the page is the last page, the status is [ListStatus.loaded] or
  /// [ListStatus.end].
  ///   - otherwise the status is kept unchanged.
  /// - if the page result is an error:
  ///   - if the page is the initial value for the last page, the status is
  /// [ListStatus.error].
  ///   - otherwise the status is kept unchanged.
  ///
  /// if [ListState.status] is [ListStatus.reloading] the status is *only*
  /// updated when all the loading pages have loaded.
  /// The new [ListState.status] after all pages have loaded will be according
  /// to the above rules.
  /// The update to [ListState.status] in this case is handled by
  /// [reloadErroredPages].
  ///
  /// Note that a new [ListState] is returned regardless of whether the
  /// status has been updated or not.
  ListState<T> _updatePage(PageKey key, Result<Page<T>> page) {
    int index = current.pagesStates.indexWhere((p) => p.key == key);
    index = index == -1 ? current.pagesStates.length : index;

    // both can be true, but can't be false; if it's not the last page it
    // must be an update.
    final isUpdate = index <= current.pagesStates.length - 1;
    final isLastPageLoaded = index >= current.pagesStates.length - 1;

    final canUpdateStatus = current.status != ListStatus.reloading;

    final List<PageState<T>?> pagesStatuses = List.of(current.pagesStates);
    if (!isUpdate) {
      pagesStatuses.add(null);
    }

    return page.incase(
      value: (v) {
        if (isUpdate) {
          v = _adjustPage(
            index,
            page: v,
            pagesStates: pagesStatuses.cast(),
          );
        }

        pagesStatuses[index] = PageState(key, PageStatus.loaded, v, null);

        final ListStatus status;
        if (isLastPageLoaded) {
          status = v.isLastPage ? ListStatus.end : ListStatus.loaded;
        } else {
          status = current.status;
        }

        return ListState(
          canUpdateStatus ? status : current.status,
          pagesStatuses.cast(),
          current.error,
        );
      },
      error: (e) {
        pagesStatuses[index] = PageState(key, PageStatus.error,
            pagesStatuses[index]?.page ?? Page.initial(), e);
        final status =
            isLastPageLoaded && !isUpdate ? ListStatus.error : current.status;
        return ListState(
          canUpdateStatus ? status : current.status,
          pagesStatuses.cast(),
          e,
        );
      },
    );
  }

  /// Adjusts the page cursor and items so other pages don't need to change
  /// when new items are inserted or old items are deleted.
  ///
  /// Adjustments to pages may result in some items being repeated in multiple
  /// pages, this is a reasonable tradeoff to not having to reload all the
  /// pages due to a single page's cursor changing.
  ///
  /// The algorithm is as follows:
  /// - remove any next page that has it's cursor less than or equal to this
  /// page's cursor. Logically, this implies that the next page's items are
  /// are present in this and previous pages
  /// - adjust the page's cursor so if the cursor is used it loads the next
  /// page.
  /// - if the cursor changed due to adjustment, the page is partly next page
  /// and thus no new pages are needed.
  /// - otherwise create a new page after page using page's cursor, and when the
  /// new page loads, [_adjustPage] will be called again. This allows multiple
  /// pages to be loaded if more than a single page size items were inserted.
  Page<T> _adjustPage(
    int index, {
    required Page<T> page,
    required List<PageState<T>> pagesStates,
  }) {
    final oldPage = index < pagesStates.length ? pagesStates[index].page : null;

    var nextPage =
        index + 1 < pagesStates.length ? pagesStates[index + 1].page : null;
    // while the page's cursor points to a page after next page remove next page
    while (nextPage != null && compareTo(page, nextPage) >= 0) {
      final nextKey = pagesStates[index + 1].key;
      final sub = subscriptions.remove(nextKey)!;
      sub.cancel();
      pagesStates.removeAt(index + 1);
      nextPage =
          index + 1 < pagesStates.length ? pagesStates[index + 1].page : null;
    }

    if (page.items.isEmpty) {
      // remove all pages after this page
      final key = pagesStates[index].key;
      scheduleMicrotask(() {
        final index = current.pagesStates.indexWhere((p) => p.key == key);
        for (var pageState in pagesStates.slice(index + 1)) {
          final sub = subscriptions.remove(pageState.key)!;
          sub.cancel();
        }
        _emit(ListState(
          current.status,
          current.pagesStates.slice(0, index + 1),
          current.error,
        ));
      });
      return page;
    }

    // If this is a new page
    // or cursor hasn't changed
    // or there's no page after this page (either this is the last page or
    // the next page hasn't been loaded yet).
    if (oldPage == null || page.cursor == oldPage.cursor || nextPage == null) {
      return page;
    }

    // Adjustment needed.

    final adjustedPage = adjustCursor(page, nextPage);
    if (adjustedPage.cursor != page.cursor) {
      // if the cursor was adjusted, we don't need to load a new page
      // as the adjustment means this page overlaps the next page
      return adjustedPage;
    } else {
      // create a new page with page.cursor
      // we can't emit before emitting the current page!
      scheduleMicrotask(() {
        final adjustmentPageState = PageState(PageKey(), PageStatus.loading,
            createAdjustmentPage(page, oldPage), null);

        _emit(ListState(
          current.status,
          [...current.pagesStates]..insert(index + 1, adjustmentPageState),
          current.error,
        ));

        // we consider this an update
        subscriptions[adjustmentPageState.key] = _NullStreamSubscription();
        _loadPageAndSubscribe(page.cursor, adjustmentPageState.key, index + 1);
      });

      return page;
    }
  }

  /// Adjust the cursor of [page] so that if used it loads [nextPage] assuming
  /// [nextPage] isn't updated.
  ///
  /// The items needs to be adjusted as well so that no items are duplicated.
  ///
  /// Due to an update to [page], the cursor of [page] will result in a
  /// different page from [nextPage] and some items may be duplicated, thus an
  /// adjustment is needed.
  ///
  /// The cursor returned may be used to reobtain [nextPage], and it should
  /// result in the same items as in [nextPage], assuming [nextPage] remained
  /// the same.
  ///
  /// Return [page.cursor] if the two pages aren't related.
  /// Return [nextPage.cursor] if [page] contains items from [nextPage] before
  /// any items not in it.
  /// Return a cursor to the last item before any items in [nextPage] otherwise.
  Page<T> adjustCursor(Page<T> page, Page<T> nextPage) {
    if (nextPage.items.isEmpty) {
      return page;
    }
    int lastToDuplicateIndex = -1;
    for (var index = 0; index < page.items.length; ++index) {
      final offer = page.items[index];
      if (nextPage.items.contains(offer)) {
        break;
      } else {
        lastToDuplicateIndex = index;
      }
    }
    if (lastToDuplicateIndex == -1) {
      final cursor = nextPage.cursor;
      return Page(
        const [],
        cursor,
        page.isLastPage,
      );
    }

    final items = page.items.slice(0, lastToDuplicateIndex + 1);
    return updateCursorOfAdjustedPage(
      Page(items, page.cursor, page.isLastPage),
    );
  }

  /// Returns a page with updated cursor for when a page is adjusted.
  ///
  /// The page parameter will have it's old cursor but the new items it holds.
  /// A cursor that loads the next items after [page.items] should be the value
  /// of the cursor of the returned [Page].
  Page<T> updateCursorOfAdjustedPage(Page<T> page);

  /// Create an adjustment page which includes all the items in [oldPage] that
  /// aren't in [page].
  Page<T> createAdjustmentPage(Page<T> page, Page<T> oldPage) {
    // The items not in page may have been deleted, we assume they aren't at
    // first but the adjustment page is updated as soon as possible to reflect
    // the true dataset.
    final items =
        oldPage.items.where((item) => !page.items.contains(item)).toList();

    // Using oldPage.cursor allows _adjustPage to skip loading a new page
    // if the page loaded has the same cursor.
    return Page(items, oldPage.cursor, page.isLastPage);
  }

  /// Defines an ordering of pages for adjustments purposes.
  ///
  /// - If [page] is empty or [page.isLastPage] is true, it's order is after
  /// other.
  /// - If [other] is empty or [other.isLastPage] is true, it's order is after
  /// page.
  /// - If both pages are last pages, they have the same
  /// order.
  /// - Otherwise compare the cursors of the pages
  int compareTo(Page<T> page, Page<T> other) {
    if (page.isLastPage && other.isLastPage) {
      return 0;
    } else if (page.isLastPage) {
      return 1;
    } else if (other.isLastPage) {
      return -1;
    } else {
      return comparePagesOrder(page, other);
    }
  }

  /// Defines an ordering of pages.
  ///
  /// the two pages are neither last pages. The ordering should depend on
  /// either the items or the cursor of the two pages.
  int comparePagesOrder(Page<T> page, Page<T> other);

  void _emit(ListState<T> state) {
    // Although it would be possible to just listen to `_states` stream and
    // update `current` value there, the order of invocation for this listener
    // would matter and it's an implementation detail in which order the stream
    // listeners are invoked.
    current = state;
    _states.add(state);
  }

  @protected
  StreamSubscription<ListState<T>> listenToNewEvents(
    void Function(ListState<T> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _states.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<void> dispose() {
    return Future.wait<void>(subscriptions.values.map((sub) => sub.cancel()))
        .then((_) => _states.close());
  }
}

/// A temporary value used when adjusting pages.
class _NullStreamSubscription<T> extends StreamSubscription<T> {
  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return Future.value(futureValue);
  }

  @override
  Future<void> cancel() {
    return Future.value();
  }

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}
