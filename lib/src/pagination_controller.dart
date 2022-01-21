import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'page_cursor.dart';
import 'helpers/or_error.dart';
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

  PageState(this.status, this.page, this.error);
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
}

/// The manager class for the live list.
/// It manages the pages subscriptions, the state of the list and loading pages
/// and retrying pages with errors
///
/// It provides a `BehaviorSubject` interface which is a stream that caches the
/// latest event and when subscribed to emits the cached event to the listener
class PaginationController<T> extends BehaviorStream<ListState<T>> {
  /// a callback for loading new pages.
  /// The cursor of the page preceding the requested page is passed or null if
  /// the requested page is the first page.
  ///
  /// There's no mandate on whether the stream should close after an error.
  final Stream<Page<T>> Function(PageCursor? cursor) onLoadPage;

  /// whether the pages returned by [PaginationController.onLoadPage] have
  /// fixed size
  final bool hasFixedPageSize;

  PaginationController(this.onLoadPage, this.hasFixedPageSize)
      : _states = StreamController<ListState<T>>.broadcast();

  StreamController<ListState<T>> _states;

  /// An ordered list of the pages updates streams subscriptions
  final subscriptions = <StreamSubscription<OrError<Page<T>>>>[];

  /// The current and last emitted list state.
  ///
  /// Refrain from using this value and listen to the stream if possible as
  /// there's no gaurantee that the event parameter of a subscription listener
  /// is the last emitted value when invoked.
  ListState<T> current = ListState.initial();

  /// Loads the next page. Typically called by the [PaginatedLiveList] widget
  void loadNextPage() {
    _emit(ListState(ListStatus.loading, current.pagesStates, current.error));
    _loadPageAndSubscribe(subscriptions.length);
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
    subscriptions[index].cancel();
    _loadPageAndSubscribe(index);
    return PageState(PageStatus.loading, pageState.page, pageState.error);
  }

  void _loadPageAndSubscribe(int pageIndex) {
    final cursor =
        pageIndex == 0 ? null : current.pagesStates[pageIndex - 1].page.cursor;
    final listStream = orErrorWrapper.call(
      () => asUnicastStream(create: () => onLoadPage(cursor)),
    );
    final subscription = listStream.listen((res) {
      _emit(_updatePage(pageIndex, res));
    });
    if (pageIndex >= subscriptions.length) {
      subscriptions.add(subscription);
    } else {
      subscriptions[pageIndex] = subscription;
    }
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
  ListState<T> _updatePage(int index, OrError<Page<T>> page) {
    // both can be true, but can't be false; if it's not the last page it
    // must be an update.
    final isUpdate = index <= current.pagesStates.length - 1;
    final isLastPageLoaded = index >= current.pagesStates.length - 1;

    final canUpdateStatus = current.status != ListStatus.reloading;

    final List<PageState<T>?> pagesStatuses =
        List.of(current.pagesStates, growable: !isUpdate);
    if (!isUpdate) {
      pagesStatuses.add(null);
    }

    return page.incase(
      value: (v) {
        pagesStatuses[index] = PageState(PageStatus.loaded, v, null);

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
        pagesStatuses[index] = PageState(
            PageStatus.error, pagesStatuses[index]?.page ?? Page.initial(), e);
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
    return _states.close().then((_) {
      return Future.wait<void>(subscriptions.map((sub) => sub.cancel()));
    });
  }
}
