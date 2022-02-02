A paginated live list widget that handles pagination, subscriptions to updates, updating pages, and error handling.

## Getting Started

The package provide a widget called `PaginatedLiveList` that takes a concrete `PaginationController` and display a paginated live list.

For usage example see the example directory.

## Implementing a PaginationController

You need to implement `Page` comparison with `PaginationController.compareTo`, `PageCursor` adjustment with `PaginationController.adjustCursor`, and loading of new pages with `PaginationController.onLoadPage`.

`PageCursor` adjustment is needed when a page changes it's cursor due to an update. The adjustment allows the PaginationController to maintain the current pages by not having to reload all the pages after the page that changed it's cursor.

See the example for an implementation of a `PaginationController`