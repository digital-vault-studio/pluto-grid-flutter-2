import 'dart:math';

import 'package:collection/collection.dart';

/// This mode is for adjusting the size of columns, etc.
///
/// [none] blocks resizing.
///
/// [normal] only changes the size of the object to be resized
/// while maintaining the size of the other siblings.
/// Also, this increases or decreases the overall area.
///
/// [pushAndPull] pushes or pulls the size of other siblings.
/// Also, this keeps the overall width.
enum PlutoResizeMode {
  none,
  normal,
  pushAndPull;

  bool get isNone => this == PlutoResizeMode.none;
  bool get isNormal => this == PlutoResizeMode.normal;
  bool get isPushAndPull => this == PlutoResizeMode.pushAndPull;
}

/// This mode automatically changes the width of columns, etc.
///
/// [none] does not automatically change the width.
///
/// [equal] changes the width equally regardless of the current size.
///
/// [scale] scales the width proportionally according to the current size.
enum PlutoAutoSizeMode {
  none,
  equal,
  scale;

  bool get isNone => this == PlutoAutoSizeMode.none;
  bool get isEqual => this == PlutoAutoSizeMode.equal;
  bool get isScale => this == PlutoAutoSizeMode.scale;
}

/// Returns the auto-sizing class according to
/// [PlutoAutoSizeMode.equal] or [PlutoAutoSizeMode.scale].
///
/// {@template exceeds_max_size}
/// If [itemMinSize] * [length] is greater than [maxSize],
/// all items are changed to [itemMinSize]
/// The total size of items exceeds [maxSize].
/// {@endtemplate}
///
/// {@template auto_size_scale_mode}
/// If [mode] is [PlutoAutoSizeMode.scale], you must pass the value of [scale].
/// If the screen size is 1,000 and the total width of the items is 500
/// scale is 1,000 / 500 = 2
/// In this case, the size of the items is doubled.
/// {@endtemplate}
class PlutoAutoSizeHelper {
  static PlutoAutoSize items({
    required double maxSize,
    required int length,
    required double itemMinSize,
    required PlutoAutoSizeMode mode,
    double? scale,
  }) {
    if (mode.isScale) assert(scale != null);

    switch (mode) {
      case PlutoAutoSizeMode.equal:
        return PlutoAutoSizeEqual(
          maxSize: maxSize,
          length: length,
          itemMinSize: itemMinSize,
        );
      case PlutoAutoSizeMode.scale:
        return PlutoAutoSizeScale(
          maxSize: maxSize,
          length: length,
          scale: scale!,
          itemMinSize: itemMinSize,
        );
      case PlutoAutoSizeMode.none:
        throw Exception('Mode cannot be called with PlutoAutoSizeMode.none.');
    }
  }
}

abstract class PlutoAutoSize {
  double getItemSize(double originalSize);
}

/// Change the width of the items equally within the [maxSize] range.
///
/// [getItemSize] must be called for the length of the items.
///
/// {@macro exceeds_max_size}
class PlutoAutoSizeEqual implements PlutoAutoSize {
  PlutoAutoSizeEqual({
    required this.maxSize,
    required this.length,
    required this.itemMinSize,
  })  : _eachSize = maxSize / length,
        _overSize = length * itemMinSize > maxSize;

  final double maxSize;

  final int length;

  final double itemMinSize;

  final double _eachSize;

  final bool _overSize;

  int _count = 1;

  double _accumulateSize = 0;

  @override
  double getItemSize(double originalSize) {
    assert(_count <= length);

    double size = _overSize ? itemMinSize : _eachSize;

    if (_overSize) {
      size = itemMinSize;
    } else {
      size = _eachSize;

      // Last item
      if (_count == length) {
        size = maxSize - _accumulateSize;

        ++_count;

        return size;
      }
    }

    _accumulateSize += size;

    ++_count;

    return size;
  }
}

/// Change the size of items according to the ratio.
///
/// [getItemSize] must be called for the length of the items.
///
/// {@macro exceeds_max_size}
///
/// {@macro auto_size_scale_mode}
class PlutoAutoSizeScale implements PlutoAutoSize {
  PlutoAutoSizeScale({
    required this.maxSize,
    required this.length,
    required this.scale,
    required this.itemMinSize,
  }) : _overSize = length * itemMinSize > maxSize;

  final double maxSize;

  final int length;

  final double scale;

  final double itemMinSize;

  final bool _overSize;

  int _count = 1;

  double _accumulateSize = 0;

  @override
  double getItemSize(double originalSize) {
    assert(_count <= length);

    double size;

    if (_overSize) {
      size = itemMinSize;
    } else {
      size = max(originalSize * scale, itemMinSize).roundToDouble();

      final remaining = maxSize - _accumulateSize - size;

      final remainingCount = length - _count;

      if (remainingCount > 0) {
        final remainingMinSize = remaining / remainingCount;

        if (remainingMinSize < itemMinSize) {
          double needingSize =
              remainingCount * (itemMinSize - remainingMinSize);

          size -= needingSize;
        }
      }

      // Last item
      if (_count == length) {
        ++_count;

        return maxSize - _accumulateSize;
      }
    }

    _accumulateSize += size;

    ++_count;

    return size;
  }
}

/// Returns a class for changing the width of a column, etc.
///
/// Cannot be called with [PlutoResizeMode.none] or [PlutoResizeMode.normal] .
///
/// {@template resize_helper_params}
/// Change the width of the item corresponding to isMainItem by [offset].
/// Negative or positive.
///
/// [items] are all siblings that will be affected
/// when the size of the item corresponding to isMainItem is changed.
///
/// [isMainItem] is a callback
/// that should return whether or not the [item] is subject to resizing.
///
/// [getItemSize] is a callback
/// that should return the size of [item].
///
/// [getItemMinSize] is a callback
/// that should return the minimum width of [item].
///
/// [setItemSize] is a callback
/// that should change the size of [item] to [size].
/// {@endtemplate}
class PlutoResizeHelper {
  static PlutoResize items<T>({
    required double offset,
    required List<T> items,
    required bool Function(T item) isMainItem,
    required double Function(T item) getItemSize,
    required double Function(T item) getItemMinSize,
    required void Function(T item, double size) setItemSize,
    required PlutoResizeMode mode,
  }) {
    switch (mode) {
      case PlutoResizeMode.pushAndPull:
        return PlutoResizePushAndPull<T>(
          offset: offset,
          items: items,
          isMainItem: isMainItem,
          getItemSize: getItemSize,
          getItemMinSize: getItemMinSize,
          setItemSize: setItemSize,
        );
      case PlutoResizeMode.none:
      case PlutoResizeMode.normal:
        throw Exception('Cannot be called with Mode set to none, normal.');
    }
  }
}

/// This is the implementation
/// that must be inherited when implementing the class according to [PlutoResizeMode].
///
/// {@macro resize_helper_params}
abstract class PlutoResize<T> {
  PlutoResize({
    required this.offset,
    required this.items,
    required this.isMainItem,
    required this.getItemSize,
    required this.getItemMinSize,
    required this.setItemSize,
  }) {
    final index = items.indexWhere((e) => isMainItem(e));
    final positiveIndex = index + 1;
    final length = items.length;

    _mainItem = items[index];

    _positiveSiblings = positiveIndex == length
        ? const Iterable.empty()
        : items.getRange(positiveIndex, length);

    _negativeSiblings = items.getRange(0, index);
  }

  final double offset;

  final List<T> items;

  final bool Function(T item) isMainItem;

  final double Function(T item) getItemSize;

  final double Function(T item) getItemMinSize;

  final void Function(T item, double size) setItemSize;

  late final T _mainItem;

  late final Iterable<T> _positiveSiblings;

  late final Iterable<T> _negativeSiblings;

  bool get isFirstMain => isMainItem(items.first);

  bool get isLastMain => isMainItem(items.last);

  T? getFirstItemPositive() {
    return _positiveSiblings.isEmpty ? null : _positiveSiblings.first;
  }

  T? getFirstItemNegative() {
    return _negativeSiblings.isEmpty ? null : _negativeSiblings.last;
  }

  T? getFirstWideItemPositive() {
    final double absOffset = offset.abs();
    return _positiveSiblings.firstWhereOrNull(
      (e) => getItemSize(e) - absOffset > getItemMinSize(e),
    );
  }

  T? getFirstWideItemNegative() {
    final double absOffset = offset.abs();
    return _negativeSiblings.lastWhereOrNull(
      (e) => getItemSize(e) - absOffset > getItemMinSize(e),
    );
  }

  Iterable<T> iterateWideItemPositive() sync* {
    final iterator = _positiveSiblings.iterator;
    while (iterator.moveNext()) {
      final current = iterator.current;

      if (getItemSize(current) > getItemMinSize(current)) {
        yield current;
      }
    }
  }

  Iterable<T> iterateWideItemNegative() sync* {
    final iterator = _negativeSiblings.toList().reversed.iterator;
    while (iterator.moveNext()) {
      final current = iterator.current;

      if (getItemSize(current) > getItemMinSize(current)) {
        yield current;
      }
    }
  }

  bool update();
}

/// Changes the size of the object to be changed by [offset]
/// and pushes or pulls the size of the remaining items.
///
/// {@macro resize_helper_params}
///
/// [update] finishes resizing and returns whether or not to change.
class PlutoResizePushAndPull<T> extends PlutoResize<T> {
  PlutoResizePushAndPull({
    required super.offset,
    required super.items,
    required super.isMainItem,
    required super.getItemSize,
    required super.getItemMinSize,
    required super.setItemSize,
  });

  @override
  bool update() {
    if (offset == 0) {
      return false;
    }

    final mainSize = getItemSize(_mainItem);
    final mainMinSize = getItemMinSize(_mainItem);

    final setMainSize =
        mainSize + offset > mainMinSize ? mainSize + offset : mainMinSize;

    if (offset > 0) {
      double remaining = offset;

      final iterPositive = iterateWideItemPositive().iterator;
      while (iterPositive.moveNext()) {
        final siblingSize = getItemSize(iterPositive.current);
        final siblingMinSize = getItemMinSize(iterPositive.current);
        final enough = siblingSize - siblingMinSize;
        final siblingOffsetToSet = enough > remaining ? remaining : enough;
        setItemSize(iterPositive.current, siblingSize - siblingOffsetToSet);
        remaining -= siblingOffsetToSet;
        if (remaining <= 0) {
          setItemSize(_mainItem, mainSize + offset);
          return true;
        }
      }

      final iterNegative = iterateWideItemNegative().iterator;
      while (iterNegative.moveNext()) {
        final siblingSize = getItemSize(iterNegative.current);
        final siblingMinSize = getItemMinSize(iterNegative.current);
        final enough = siblingSize - siblingMinSize;
        final siblingOffsetToSet = enough > remaining ? remaining : enough;
        setItemSize(iterNegative.current, siblingSize - siblingOffsetToSet);
        remaining -= siblingOffsetToSet;
        if (remaining <= 0) {
          setItemSize(_mainItem, mainSize + offset);
          return true;
        }
      }

      if (offset == remaining) {
        return false;
      }

      setItemSize(_mainItem, mainSize + (offset - remaining));

      return true;
    } else {
      if (isFirstMain || isLastMain) {
        if (setMainSize == mainSize) {
          return false;
        }
        final firstSiblingItem =
            isFirstMain ? getFirstItemPositive() : getFirstItemNegative();
        if (firstSiblingItem == null) {
          return false;
        }
        setItemSize(_mainItem, setMainSize);
        final firstSiblingItemWidth = getItemSize(firstSiblingItem);
        setItemSize(
          firstSiblingItem,
          firstSiblingItemWidth + mainSize - setMainSize,
        );
        return true;
      }

      double remainingNegative = offset.abs() - (mainSize - setMainSize);
      if (remainingNegative > 0) {
        final iterNegative = iterateWideItemNegative().iterator;
        while (iterNegative.moveNext()) {
          final siblingSize = getItemSize(iterNegative.current);
          final siblingMinSize = getItemMinSize(iterNegative.current);
          final enough = siblingSize - siblingMinSize;
          final siblingOffsetToSet =
              enough > remainingNegative ? remainingNegative : enough;
          setItemSize(iterNegative.current, siblingSize - siblingOffsetToSet);
          remainingNegative -= siblingOffsetToSet;
          if (remainingNegative <= 0) {
            break;
          }
        }
      }

      if (mainSize == setMainSize &&
          remainingNegative == offset.abs() - (mainSize - setMainSize)) {
        return false;
      }

      setItemSize(_mainItem, setMainSize);

      final firstPositiveItem = getFirstItemPositive();
      assert(firstPositiveItem != null);
      final firstPositiveItemSize = getItemSize(firstPositiveItem as T);
      setItemSize(
        firstPositiveItem,
        firstPositiveItemSize + offset.abs() - remainingNegative,
      );
    }

    return true;
  }
}
