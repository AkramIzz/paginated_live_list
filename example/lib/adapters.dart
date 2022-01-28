import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paginated_live_list/paginated_live_list.dart';

class Ordering {
  final String field;
  final bool descending;

  Ordering(this.field, {this.descending = false});
}

class FirestorePageCursor implements PageCursor {
  final List values;

  FirestorePageCursor(this.values);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    } else if (other is! FirestorePageCursor) {
      return false;
    } else if (values.length != other.values.length) {
      return false;
    }
    for (int i = 0; i < values.length; ++i) {
      if (values[i] != other.values[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return '$runtimeType($values)';
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
    required List<Ordering> orderBy,
    required DocumentMapper<T> documentMapper,
    int pageSize = kDefaultPageSize,
    bool includeMetadataChanges = false,
  }) {
    assert(cursor == null || cursor.values.isNotEmpty);

    var query = limit(pageSize);
    for (final orderField in orderBy) {
      query =
          query.orderBy(orderField.field, descending: orderField.descending);
    }
    if (cursor != null) {
      query = query.startAfter(cursor.values);
    }

    return query
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .map((snapshot) {
      if (snapshot.size == 0) {
        return Page<T>(const [], FirestorePageCursor([]), true);
      }

      final lastData = snapshot.docs.last.data();
      return Page<T>(
        snapshot.docs.map(documentMapper).toList(),
        FirestorePageCursor(
          List.generate(orderBy.length, (i) => lastData[orderBy[i].field]),
        ),
        snapshot.size != pageSize,
      );
    });
  }
}

typedef DocumentMapper<T> = T Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc);
