class LruSet<E> {
  final int maximumSize;

  LruSet(this.maximumSize);

  final _entries = Map<E, _LinkedEntry<E>>();

  _LinkedEntry<E>? head;
  _LinkedEntry<E>? tail;

  E? put(E value) {
    _LinkedEntry? removedEntry;

    if (_entries.containsKey(value)) {
      _updateMru(_entries[value]!);
    } else {
      if (_entries.length >= maximumSize) {
        removedEntry = _removeLru();
      }

      final entry = _LinkedEntry(value);
      _insertEntry(entry);
    }

    return removedEntry?.value;
  }

  bool contains(E value) {
    return _entries[value] != null;
  }

  int get length => _entries.length;

  Iterable<E> iterable() {
    return _entries.keys;
  }

  _LinkedEntry _removeLru() {
    assert(tail != null);
    final lru = tail!;

    if (head == tail) {
      head = tail = null;
    } else {
      tail = tail?.next;
    }

    _entries.remove(lru.value);
    return lru;
  }

  void _updateMru(_LinkedEntry<E> entry) {
    if (entry == head) {
      return;
    }
    if (entry == tail) {
      tail = entry.next ?? entry;
    }

    entry.prev?.next = entry.next;
    entry.next?.prev = entry.prev;
    head?.next = entry;
    entry.prev = head;
    entry.next = null;
    head = entry;
  }

  void _insertEntry(_LinkedEntry<E> entry) {
    tail ??= entry;
    entry.prev = head;
    head?.next = entry;
    head = entry;
    _entries[entry.value] = entry;
  }
}

class _LinkedEntry<E> {
  _LinkedEntry(this.value);

  E value;

  _LinkedEntry<E>? next;
  _LinkedEntry<E>? prev;
}
