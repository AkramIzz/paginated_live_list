import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:example/adapters.dart';
import 'package:paginated_live_list/paginated_live_list.dart';

import 'offer_model.dart';

extension LetValue<T extends Object> on T {
  let<R>(R Function(T value) callback) {
    callback(this);
  }
}

abstract class OffersRepository {
  Future<List<Offer>> createMultiple(List<Offer> offers);
  Future<void> delete(Offer offer);
  Future<void> deleteAll(List<Offer> offers);
  Stream<Page<Offer>> list(covariant PageCursor? cursor);
  Page<Offer> createPageCursor(Page<Offer> page);

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

  Future<void> deleteAll(List<Offer> offers) {
    final batch = FirebaseFirestore.instance.batch();
    for (var offer in offers) {
      batch.delete(ref.doc(offer.id));
    }
    return batch.commit();
  }

  @override
  Stream<Page<Offer>> list(FirestorePageCursor? cursor) {
    return ref.paginatedSnapshots(
      cursor,
      documentMapper: (doc) => Offer.fromJson(doc.data()),
    );
  }

  @override
  Page<Offer> createPageCursor(Page<Offer> page) {
    final last = page.items.last;
    return Page(
        page.items,
        FirestorePageCursor(Timestamp.fromDate(last.createdAt)),
        page.isLastPage);
  }
}
