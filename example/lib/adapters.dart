import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:live_paginated_list/live_paginated_list.dart';

class FirestorePageCursor<T> implements PageCursor {
  final DocumentSnapshot<T>? last;

  FirestorePageCursor(this.last);
}

const int kDefaultPageSize = 10;

/// Paginates a firestore query
///
/// If the cursor is null, the first page is returned
/// otherwise the cursor document is expected to be not null and the page
/// starting after the cursor document is returned.
///
/// The page returned will always have a cursor to it's last document unless
/// the page is empty.
///
/// If new documents are added to the last page, the page is updated accordingly
/// including [Page.isLastPage], thus a new page may be available for request.
extension PaginatedQuerySnapshots on Query<Map<String, dynamic>> {
  Stream<Page<T>> paginatedSnapshots<T, E>(
    FirestorePageCursor? cursor, {
    required DocumentMapper<T> documentMapper,
    int pageSize = kDefaultPageSize,
    bool includeMetadataChanges = false,
  }) {
    assert(cursor == null || cursor.last != null);

    var query = limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(cursor.last!);
    }

    return query
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .map((snapshot) {
      if (snapshot.size == 0) {
        return Page(const [], FirestorePageCursor(null), true);
      }

      return Page<T>(
        snapshot.docs.map(documentMapper).toList(),
        FirestorePageCursor(snapshot.docs.last),
        snapshot.size != pageSize,
      );
    });
  }
}

typedef DocumentMapper<T> = T Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc);
