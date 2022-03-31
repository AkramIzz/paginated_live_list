A package that handles pagination, subscriptions to updates, updating pages, and error handling.

## Getting Started
The package provides a set of widgets that takes a concrete `PaginationController` and implement a live list behavior by controlling loading of items when needed, subscriptions to pages updates, updating the list and notifying the view.

Specifying the view itself is up to the programmer.

There is also a fully featured `PaginatedLiveList` widget that uses the basic set of widgets but with the view being a ListView.

For usage example see the example directory.

## Installation
Add `paginated_live_list` as a dependency to your project `pubspec.yaml` and run `flutter pub get` to install all your dependencies.

```yaml
# in pubspec.yaml
dependencies:
  paginated_live_list:
```

## Basic Concepts
### The Page Cursor
Every page has its own cursor that serves as a pointer for loading the next page. The cursor used to load the first page is `null` since it has no preceding pages. It's up to the developer to define a concrete `PageCursor`.

```dart
class IntPageCursor implements PageCursor {
  final int nextPage;

  IntPageCursor(this.nextPage);
}
```

### The Page Class
Contains the list of `items` in the page, a `cursor` defined by the developer, and a boolean `isLastPage` to indicate whether or not there is more pages to load.

## Usage
### Import The Package
```dart
import 'package:paginated_live_list/paginated_live_list.dart';
```

### Define Your Items Class
`Item` class needs to be immutable and implement the equality operator

```dart
class Item {
  final String id;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.createdAt,
  });

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object? other) {
    if (other is Item && id == other.id) {
      return true;
    } else {
      return false;
    }
  }
}
```

### Implement a PageCursor
You must implement the equality operator.

```dart
class CustomPageCursor implements PageCursor {
  final String? lastItemId;

  CustomPageCursor(this.lastItemId);

  @override
  int get hashCode => lastItemId.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    } else if (other is! CustomPageCursor) {
      return false;
    }

    return lastItemId == other.lastItemId;
  }
}
```

### Implement a PaginationController
Extend the PaginationController and implement 
- `PaginationController.comparePagesOrder`: for `Page` ordering.

  It should simply determine the order of the two pages passed in as parameters using the cursors of the pages or their items.

```dart
  @override
  int comparePagesOrder(Page<Item> page, Page<Item> other) {
    // Assuming the pages are in ascending order.
    // for descending order multiply by -1.
    return page.items.last.createdAt.compareTo(other.items.last.createdAt);
  }
```

- `PaginationController.updateCursorOfAdjustedPage`: for adjustment of page cursors.
  
  Adjustment is needed when a page changes it's cursor due to an update. The adjustment allows the PaginationController to maintain the current pages by not having to reload all the pages after the page that changed it's cursor.

```dart
  @override
  Page<Offer> updateCursorOfAdjustedPage(Page<Item> page) {
    final last = page.items.last;
    return Page(
        page.items,
        CustomPageCursor(last.id, last.createdAt),
        page.isLastPage);
  }
```

- `PaginationController.onLoadPage`: for loading new pages.

  This should provide a stream for a page that emits the page then each time the page is updated. All kinds of updates are supported: Updating an item(s), deleting an item(s), and adding a new item(s).

```dart
  @override
  Stream<Page<T>> onLoadPage(CustomPageCursor cursor) {
    return dataSource.list(after: cursor.lastItemId, size: 10).map((items) =>
        Page(items, CustomPageCursor(items.lastOrNull?.id), items.length < 10));
  }
```

### Define the View
If you want to have a ListView, you may use the `LivePaginatedList` widget.

```dart
  Widget build(BuildContext context) {
    return PaginationControllerProvider<Offer>(
      create: (context) => CustomPaginationController(),
      child: PaginatedLiveList<Offer>(
        controller: null,
        itemBuilder: (context, state, index) {
          final item = state.items[index];
          return ItemWidget(item: item);
        },
      ),
    );
  }
```

For other scroll views (e.g. GridView) you need to use the basic widgets. Namely, the `PaginationBehavior`, the `ViewBuilder`. See the `LivePaginatedList` widget implementation for an example.
