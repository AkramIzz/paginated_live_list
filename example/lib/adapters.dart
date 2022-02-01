import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paginated_live_list/paginated_live_list.dart';

class FirestorePageCursor implements PageCursor {
  final Timestamp? timestamp;

  FirestorePageCursor(this.timestamp);

  @override
  int get hashCode => timestamp.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    } else if (other is! FirestorePageCursor) {
      return false;
    }

    return timestamp == other.timestamp;
  }

  @override
  String toString() {
    return '$runtimeType($timestamp)';
  }
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
    assert(cursor == null || cursor.timestamp != null);

    var query = orderBy('createdAt', descending: true).limit(pageSize);
    if (cursor != null) {
      query = query.startAfter([cursor.timestamp]);
    }

    return query
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .map((snapshot) {
      if (snapshot.size == 0) {
        return Page<T>(const [], FirestorePageCursor(null), true);
      }

      final lastData = snapshot.docs.last.data();
      return Page<T>(
        snapshot.docs.map(documentMapper).toList(),
        FirestorePageCursor(lastData['createdAt']),
        snapshot.size != pageSize,
      );
    });
  }
}

typedef DocumentMapper<T> = T Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc);
