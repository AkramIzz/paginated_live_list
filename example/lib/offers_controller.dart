import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:example/adapters.dart';
import 'package:paginated_live_list/paginated_live_list.dart';

import 'package:example/offer_model.dart';
import 'package:example/offers_repository.dart';

class OffersController extends PaginationController<Offer> {
  final generator = Random();

  Future<void> onDeleteOffer(Offer offer) {
    return OffersRepository.instance.delete(offer);
  }

  var _price = 0;
  var _day = 0;
  Future<void> onAddOffers() async {
    final startDate = DateTime.now().add(Duration(days: _day));
    _day += 11;

    await OffersRepository.instance.createMultiple(
      List.generate(10, (index) {
        final date = startDate.add(Duration(days: index + 1));
        return Offer(
          id: null,
          createdAt: date,
          availableUntil: date.add(Duration(days: generator.nextInt(9) + 1)),
          price: _price++,
          author: 'User ${generator.nextInt(100)}',
        );
      }),
    );
  }

  Future<void> onClearOffers() async {
    _price = 0;
    _day = 0;
    await OffersRepository.instance.deleteAll(current.items);
  }

  @override
  Stream<Page<Offer>> onLoadPage(PageCursor? cursor) {
    return OffersRepository.instance.list(cursor);
  }

  int compareTo(Page<Offer> page, Page<Offer> other) {
    if (other.items.isEmpty || page.items.isEmpty) {
      return other.items.isEmpty ? -1 : 1;
    }

    return -1 * page.items.last.createdAt.compareTo(other.items.last.createdAt);
  }

  @override
  Page<Offer> adjustCursor(Page<Offer> page, Page<Offer> nextPage) {
    if (nextPage.items.isEmpty) {
      return page;
    }
    int lastToDuplicateIndex = -1;
    for (var index = 0; index < page.items.length; ++index) {
      final offer = page.items[index];
      if (nextPage.items.firstWhereOrNull((it) => it.id == offer.id) != null) {
        break;
      } else {
        lastToDuplicateIndex = index;
      }
    }
    if (lastToDuplicateIndex == -1) {
      final cursorOffer = nextPage.items.last;
      return Page(
        const [],
        FirestorePageCursor([Timestamp.fromDate(cursorOffer.createdAt)]),
        page.isLastPage,
      );
    }
    final lastToDuplicate = page.items[lastToDuplicateIndex];

    return Page(
      page.items.slice(0, lastToDuplicateIndex + 1),
      FirestorePageCursor([Timestamp.fromDate(lastToDuplicate.createdAt)]),
      page.isLastPage,
    );
  }
}
