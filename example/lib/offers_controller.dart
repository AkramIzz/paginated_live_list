import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:example/adapters.dart';
import 'package:paginated_live_list/paginated_live_list.dart';

import 'package:example/offer_model.dart';
import 'package:example/offers_repository.dart';

class OffersController extends PaginationController<Offer> {
  final generator = Random();

  OffersController() {
    listen((state) {
      print('');
      print('=== Update ===');
      print('[');
      state.pagesStates.forEach((pageState) {
        final page = pageState.page;
        print(
            '${page.items.map((it) => it.price).toList()} cursor: ${page.cursor}');
      });
      print(']');
      print('=== End    ===');
      print('');
    });
  }

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
    print(
        'comparing pages: ${page.items.map((o) => o.price).toList()}, ${other.items.map((o) => o.price).toList()}');
    print('${page == other}');
    if (other.items.length == 0 || page.items.length == 0) {
      return other.items.length == 0 ? -1 : 1;
    }

    return -1 * page.items.last.createdAt.compareTo(other.items.last.createdAt);
  }

  @override
  PageCursor adjustCursor(Page<Offer> page, Page<Offer> nextPage) {
    print('adjusting cursor');
    if (nextPage.items.isEmpty) {
      print('cursor maintained');
      return page.cursor!;
    }
    print(
        'adjusting cursor: ${page.items.last.price}:${page.items.last.createdAt}, ${nextPage.items.last.price}:${nextPage.items.last.createdAt}');
    Offer lastNotContained = nextPage.items.last;
    for (var offer in page.items) {
      if (nextPage.items.firstWhereOrNull((it) => it.id == offer.id) != null) {
        break;
      } else {
        lastNotContained = offer;
      }
    }

    print(
        'new cursor: ${lastNotContained.price}:${lastNotContained.createdAt}');
    return FirestorePageCursor(
      [Timestamp.fromDate(lastNotContained.createdAt)],
    );
  }
}
