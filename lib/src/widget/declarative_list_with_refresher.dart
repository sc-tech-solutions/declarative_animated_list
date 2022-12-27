import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:declarative_animated_list/src/algorithm/strategy.dart';
import 'package:declarative_animated_list/src/widget/declarative_list.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class DeclarativeListWithRefresher<T extends Object> extends StatefulWidget {
  ///Set of items to be displayed in the list
  final List<T> items;

  ///Builder function for inserted items
  final AnimatedItemBuilder<T> itemBuilder;

  ///Builder function for removed items
  final AnimatedItemBuilder<T> removeBuilder;

  ///Callback that is used to determine if two given objects are equal. [==]
  ///operator will be used by default.
  final EqualityCheck<T>? equalityCheck;

  ///Initial items count for the list, gets defined automatically
  final int initialItemCount;

  ///Refer to [AnimatedListState.insertItem]
  final Duration? insertDuration;

  ///Refer to [AnimatedListState.removeItem]
  final Duration? removeDuration;

  ///Refer to [AnimatedList.scrollDirection]
  final Axis scrollDirection;

  ///Refer to [AnimatedList.scrollController]
  final ScrollController? scrollController;

  ///Refer to [AnimatedList.padding]
  final EdgeInsetsGeometry? padding;

  ///Refer to [AnimatedList.physics]
  final ScrollPhysics? physics;

  ///Refer to [AnimatedList.primary]
  final bool? primary;

  ///Refer to [AnimatedList.reverse]
  final bool reverse;

  ///Refer to [AnimatedList.shrinkWrap]
  final bool shrinkWrap;

  final RefreshController? refreshController;
  final Function()? onRefresh;

  const DeclarativeListWithRefresher({
    required this.items,
    required this.itemBuilder,
    required this.removeBuilder,
    this.equalityCheck,
    this.scrollDirection = Axis.vertical,
    this.insertDuration,
    this.removeDuration,
    this.scrollController,
    this.refreshController,
    this.onRefresh,
    this.padding,
    this.physics,
    this.primary,
    this.reverse = false,
    this.shrinkWrap = false,
    Key? key,
  })  : this.initialItemCount = items.length,
        super(key: key);

  @override
  _DeclarativeListWithRefresherState<T> createState() =>
      _DeclarativeListWithRefresherState<T>();
}

class _DeclarativeListWithRefresherState<T extends Object>
    extends State<DeclarativeListWithRefresher<T>> {
  // TODO: Remove this.
  // final GlobalKey<AnimatedListState> _animatedListKey =
  //     GlobalKey<AnimatedListState>();
  final GlobalKey<CustomAnimatedListState> _animatedListKey =
      GlobalKey<CustomAnimatedListState>();
  late List<T> items;

  @override
  void initState() {
    super.initState();
    this.items = List<T>.from(this.widget.items);
  }

  @override
  void didUpdateWidget(final DeclarativeListWithRefresher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateList(oldWidget.items, this.widget.items);
  }

  void _updateList(final List<T> oldList, final List<T> newList) {
    final DifferenceResult result = DifferentiatingStrategyFactory()
        .create()
        .differentiate(ListsDifferenceRequest(oldList, newList,
            equalityCheck: this.widget.equalityCheck));
    final DifferenceConsumer consumer = _AnimatedListDifferenceConsumer<T>(
      this._animatedListKey.currentState!,
      oldList,
      newList,
      this.widget.removeBuilder,
      removeDuration: this.widget.removeDuration,
      insertDuration: this.widget.insertDuration,
    );
    result.dispatchUpdates(consumer);
  }

  @override
  Widget build(final BuildContext context) {
    return CustomAnimatedList(
      key: _animatedListKey,
      initialItemCount: widget.initialItemCount,
      itemBuilder: (
        final BuildContext context,
        final int index,
        final Animation<double> animation,
      ) =>
          this.widget.itemBuilder(
                context,
                this.widget.items[index],
                index,
                animation,
              ),
      scrollDirection: widget.scrollDirection,
      controller: widget.scrollController,
      refreshController: widget.refreshController,
      onRefresh: widget.onRefresh,
      padding: widget.padding,
      physics: widget.physics,
      primary: widget.primary,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
    );
  }
}

class _AnimatedListDifferenceConsumer<T> extends DifferenceConsumer {
  // TODO: Remove this.
  // final AnimatedListState state;
  final CustomAnimatedListState state;
  final List<T> oldList;
  final List<T> updatedList;
  final AnimatedItemBuilder<T> removeBuilder;
  final Duration? removeDuration;
  final Duration? insertDuration;

  _AnimatedListDifferenceConsumer(
      this.state, this.oldList, this.updatedList, this.removeBuilder,
      {this.insertDuration, this.removeDuration});

  @override
  void onInserted(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      _insertItem(i);
    }
  }

  @override
  void onRemoved(final int position, final int count) {
    for (int i = position + count - 1; i >= position; i--) {
      _removeItem(i);
    }
  }

  @override
  void onMoved(final int oldPosition, final int newPosition) {
    _removeItem(oldPosition);
    _insertItem(newPosition);
  }

  void _insertItem(int position) {
    if (insertDuration != null) {
      state.insertItem(position, duration: insertDuration!);
    } else {
      state.insertItem(position);
    }
  }

  void _removeItem(final int index) {
    final AnimatedListRemovedItemBuilder builder =
        (final BuildContext context, final Animation<double> animation) =>
            this.removeBuilder(
              context,
              oldList[index],
              index,
              animation,
            );
    if (removeDuration != null) {
      state.removeItem(index, builder, duration: removeDuration!);
    } else {
      state.removeItem(index, builder);
    }
  }
}

// The default insert/remove animation duration.
const Duration _kDuration = Duration(milliseconds: 300);

class CustomAnimatedList extends StatefulWidget {
  /// Creates a scrolling container that animates items when they are inserted
  /// or removed.
  const CustomAnimatedList({
    Key? key,
    required this.itemBuilder,
    this.initialItemCount = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.refreshController,
    this.onRefresh,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  })  : assert(itemBuilder != null),
        assert(initialItemCount != null && initialItemCount >= 0),
        super(key: key);

  /// Called, as needed, to build list item widgets.
  ///
  /// List items are only built when they're scrolled into view.
  ///
  /// The [AnimatedListItemBuilder] index parameter indicates the item's
  /// position in the list. The value of the index parameter will be between 0
  /// and [initialItemCount] plus the total number of items that have been
  /// inserted with [AnimatedListState.insertItem] and less the total number of
  /// items that have been removed with [AnimatedListState.removeItem].
  ///
  /// Implementations of this callback should assume that
  /// [AnimatedListState.removeItem] removes an item immediately.
  final AnimatedListItemBuilder itemBuilder;

  /// {@template flutter.widgets.animatedList.initialItemCount}
  /// The number of items the list will start with.
  ///
  /// The appearance of the initial items is not animated. They
  /// are created, as needed, by [itemBuilder] with an animation parameter
  /// of [kAlwaysCompleteAnimation].
  /// {@endtemplate}
  final int initialItemCount;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  ///
  /// Must be null if [primary] is true.
  ///
  /// A [ScrollController] serves several purposes. It can be used to control
  /// the initial scroll position (see [ScrollController.initialScrollOffset]).
  /// It can be used to control whether the scroll view should automatically
  /// save and restore its scroll position in the [PageStorage] (see
  /// [ScrollController.keepScrollOffset]). It can be used to read the current
  /// scroll position (see [ScrollController.offset]), or change it (see
  /// [ScrollController.animateTo]).
  final ScrollController? controller;

  /// Whether this is the primary scroll view associated with the parent
  /// [PrimaryScrollController].
  ///
  /// On iOS, this identifies the scroll view that will scroll to top in
  /// response to a tap in the status bar.
  ///
  /// Defaults to true when [scrollDirection] is [Axis.vertical] and
  /// [controller] is null.
  final bool? primary;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// Defaults to matching platform conventions.
  final ScrollPhysics? physics;

  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  /// If the scroll view does not shrink wrap, then the scroll view will expand
  /// to the maximum allowed size in the [scrollDirection]. If the scroll view
  /// has unbounded constraints in the [scrollDirection], then [shrinkWrap] must
  /// be true.
  ///
  /// Shrink wrapping the content of the scroll view is significantly more
  /// expensive than expanding to the maximum allowed size because the content
  /// can expand and contract during scrolling, which means the size of the
  /// scroll view needs to be recomputed whenever the scroll position changes.
  ///
  /// Defaults to false.
  final bool shrinkWrap;

  /// The amount of space by which to inset the children.
  final EdgeInsetsGeometry? padding;

  final RefreshController? refreshController;
  final Function()? onRefresh;

  /// The state from the closest instance of this class that encloses the given
  /// context.
  ///
  /// This method is typically used by [AnimatedList] item widgets that insert
  /// or remove items in response to user input.
  ///
  /// ```dart
  /// AnimatedListState animatedList = AnimatedList.of(context);
  /// ```
  static CustomAnimatedListState? of(BuildContext context,
      {bool nullOk = false}) {
    assert(context != null);
    assert(nullOk != null);
    final CustomAnimatedListState? result =
        context.findAncestorStateOfType<CustomAnimatedListState>();
    if (nullOk || result != null) return result;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
          'AnimatedList.of() called with a context that does not contain an AnimatedList.'),
      ErrorDescription(
          'No AnimatedList ancestor could be found starting from the context that was passed to AnimatedList.of().'),
      ErrorHint(
          'This can happen when the context provided is from the same StatefulWidget that '
          'built the AnimatedList. Please see the AnimatedList documentation for examples '
          'of how to refer to an AnimatedListState object:'
          '  https://api.flutter.dev/flutter/widgets/AnimatedListState-class.html'),
      context.describeElement('The context used was')
    ]);
  }

  @override
  CustomAnimatedListState createState() => CustomAnimatedListState();
}

/// The state for a scrolling container that animates items when they are
/// inserted or removed.
///
/// When an item is inserted with [insertItem] an animation begins running. The
/// animation is passed to [AnimatedList.itemBuilder] whenever the item's widget
/// is needed.
///
/// When an item is removed with [removeItem] its animation is reversed.
/// The removed item's animation is passed to the [removeItem] builder
/// parameter.
///
/// An app that needs to insert or remove items in response to an event
/// can refer to the [AnimatedList]'s state with a global key:
///
/// ```dart
/// GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();
/// ...
/// AnimatedList(key: listKey, ...);
/// ...
/// listKey.currentState.insert(123);
/// ```
///
/// [AnimatedList] item input handlers can also refer to their [AnimatedListState]
/// with the static [AnimatedList.of] method.
class CustomAnimatedListState extends State<CustomAnimatedList>
    with TickerProviderStateMixin<CustomAnimatedList> {
  final GlobalKey<SliverAnimatedListState> _sliverAnimatedListKey = GlobalKey();

  /// Insert an item at [index] and start an animation that will be passed
  /// to [AnimatedList.itemBuilder] when the item is visible.
  ///
  /// This method's semantics are the same as Dart's [List.insert] method:
  /// it increases the length of the list by one and shifts all items at or
  /// after [index] towards the end of the list.
  void insertItem(int index, {Duration duration = _kDuration}) {
    _sliverAnimatedListKey.currentState!.insertItem(index, duration: duration);
  }

  /// Remove the item at [index] and start an animation that will be passed
  /// to [builder] when the item is visible.
  ///
  /// Items are removed immediately. After an item has been removed, its index
  /// will no longer be passed to the [AnimatedList.itemBuilder]. However the
  /// item will still appear in the list for [duration] and during that time
  /// [builder] must construct its widget as needed.
  ///
  /// This method's semantics are the same as Dart's [List.remove] method:
  /// it decreases the length of the list by one and shifts all items at or
  /// before [index] towards the beginning of the list.
  void removeItem(int index, AnimatedListRemovedItemBuilder builder,
      {Duration duration = _kDuration}) {
    _sliverAnimatedListKey.currentState!
        .removeItem(index, builder, duration: duration);
  }

  /// Controller for pull to refresh in the duos tab
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  Widget build(BuildContext context) {
    return SmartRefresher(
      onRefresh: widget.onRefresh,
      controller: widget.refreshController ?? _refreshController,
      child: CustomScrollView(
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: widget.controller,
        primary: widget.primary,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        slivers: <Widget>[
          SliverPadding(
            padding: widget.padding ?? const EdgeInsets.all(0),
            sliver: SliverAnimatedList(
              key: _sliverAnimatedListKey,
              itemBuilder: widget.itemBuilder,
              initialItemCount: widget.initialItemCount,
            ),
          ),
        ],
      ),
    );
  }
}
