import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:example/adapters.dart';
import 'package:live_paginated_list/live_paginated_list.dart';

import 'offer_model.dart';

extension LetValue<T extends Object> on T {
  let<R>(R Function(T value) callback) {
    callback(this);
  }
}

abstract class OffersRepository {
  Future<List<Offer>> createMultiple(List<Offer> offers);
  Future<void> delete(Offer offer);
  Stream<Page<Offer>> list(covariant PageCursor? cursor);

  static final OffersRepository instance = FirebaseOffersRepository();
}

class FirebaseOffersRepository implements OffersRepository {
  final ref = FirebaseFirestore.instance.collection('offers');

  @override
  Future<List<Offer>> createMultiple(List<Offer> _offers) async {
    final offers = List.of(_offers, growable: false);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < offers.length; ++i) {
      final doc = ref.doc();
      offers[i] = offers[i].copyWith(id: doc.id);
      batch.set(doc, offers[i].toJson());
    }

    await batch.commit();
    return offers;
  }

  @override
  Future<void> delete(Offer offer) {
    return ref.doc(offer.id).delete();
  }

  @override
  Stream<Page<Offer>> list(FirestorePageCursor? cursor) {
    final query = ref.orderBy('createdAt', descending: false);
    return query.paginatedSnapshots(
      cursor,
      documentMapper: (doc) => Offer.fromJson(doc.data()),
    );
  }
}
