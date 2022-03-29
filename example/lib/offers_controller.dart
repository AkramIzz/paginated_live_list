import 'dart:math';

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

  @override
  int comparePagesOrder(Page<Offer> page, Page<Offer> other) {
    // Since pages are in descending order, we multiply the compareTo result by
    // -1.
    return -1 * page.items.last.createdAt.compareTo(other.items.last.createdAt);
  }

  @override
  Page<Offer> updateCursorOfAdjustedPage(Page<Offer> page) {
    return OffersRepository.instance.createPageCursor(page);
  }
}
