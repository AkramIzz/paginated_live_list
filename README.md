# live_paginated_list

A live paginated list widget

## Getting Started

For usage example see the example directory

## Road Map

- [ ] add null safety
- [ ] add tests
- [ ] contribution and issues guide
- [ ] support slivers
- [ ] support grid view
- [ ] documentation and examples
- [ ] update widget with more options and builders:
  - item, firstPageError, newPageError, oldPageError, firstPageProgress, newPageProgress, oldPageProgress, emptyList, endOfList
- [ ] refresh: load first page -> remove all pages -> add first page
- [ ] make WidgetAwarePagesSubscriptionsHandler an opt-in option
- [ ] lru cache for pages (not subscriptions but actually remove pages from memory)
- [ ] support item insertion and removal animations (with diffing or with changes supplied by user)
