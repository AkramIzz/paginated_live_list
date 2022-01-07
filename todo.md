Known issues:
    - Last page subscription doesn't get paused if hasFixedSize is true
    - Possiblity of duplicates if a page's cursor is updated due to a change in page items (item deleted, item inserted)
    - WidgetAwareSubscriptionsHandler will resume a subscription when one of it's items is visible even if it was paused by another entity


Why change:
    - Allow loading of new pages even when there's an error in a previous page
    - ListState updates due to reloading wait for all loading pages before emitting a new ListState.status
    - Simplifies the logic for the ListState.status
    - Makes the implementation easier and more readable with no tradeoffs