import 'dart:math';

import 'package:example/offer_model.dart';
import 'package:example/offers_repository.dart';
import 'package:live_paginated_list/live_paginated_list.dart';

class OffersController extends PaginationController<Offer> {
  OffersController() : super(_onLoadPage, false);

  final generator = Random();

  Future<void> onDeleteOffer(Offer offer) {
    return OffersRepository.instance.delete(offer);
  }

  Future<void> onAddOffers() async {
    final now = DateTime.now();

    await OffersRepository.instance.createMultiple(
      List.generate(10, (index) {
        return Offer(
          id: null,
          createdAt: now,
          availableUntil: now.add(Duration(days: generator.nextInt(9) + 1)),
          price: generator.nextInt(5000) + 1000,
          author: 'User ${generator.nextInt(100)}',
        );
      }),
    );
  }

  Future<void> onClearOffers() async {
    await OffersRepository.instance.deleteAll(current.items);
  }
}

Stream<Page<Offer>> _onLoadPage(PageCursor? cursor) {
  return OffersRepository.instance.list(cursor).map((page) {
    print(page.cursor);
    return page;
  });
}
