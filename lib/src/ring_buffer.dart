import 'dart:collection';

class RingBuffer<T> {
  final int _capacity;
  final List<T?> _buffer;
  int _head = 0; // Points to the next position to write.
  int _tail = 0; // Points to the oldest item.
  int _size = 0; // Tracks the number of elements in the buffer.

  RingBuffer(this._capacity)
      : assert(_capacity > 0),
        _buffer = List<T?>.filled(_capacity, null);

  bool get isFull => _size == _capacity;
  bool get isEmpty => _size == 0;

  List<T?> get source => UnmodifiableListView(_buffer);
  int get head => _head;
  int get capacity => _capacity;

  /// Adds an item to the buffer. Overwrites the oldest item if the buffer is full.
  void add(T item) {
    _buffer[_head] = item;
    if (isFull) {
      _tail = (_tail + 1) % _capacity; // Move tail forward when overwriting.
    } else {
      _size++;
    }
    _head = (_head + 1) % _capacity;
  }

  /// Removes and returns the oldest item in the buffer. Throws an error if empty.
  T remove() {
    if (isEmpty) {
      throw StateError('Buffer is empty');
    }
    final item = _buffer[_tail];
    _buffer[_tail] = null; // Clear the slot.
    _tail = (_tail + 1) % _capacity;
    _size--;
    return item!;
  }

  /// Reads the contents of the buffer without removing items.
  List<T> toList() {
    final list = <T?>[];
    for (int i = 0; i < _size; i++) {
      list.add(_buffer[(_tail + i) % _capacity]);
    }
    return list.cast<T>();
  }
}
