import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One sealed state per screen (see `8 · Handoff · Layar & State.png`).
sealed class ViewState<T> {
  const ViewState();
}

class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty();
}

class ViewError<T> extends ViewState<T> {
  const ViewError(this.error);
  final Object error;
}

/// Cached data shown while offline, with the last server sync time.
class ViewOffline<T> extends ViewState<T> {
  const ViewOffline(this.data, this.lastSync);
  final T data;
  final DateTime? lastSync;
}

class ViewData<T> extends ViewState<T> {
  const ViewData(this.data);
  final T data;
}

/// Maps an [AsyncValue] plus connectivity into a [ViewState].
ViewState<T> toViewState<T>(
  AsyncValue<T> value, {
  required bool offline,
  DateTime? lastSync,
  bool Function(T data)? isEmpty,
}) {
  if (value.hasValue) {
    final data = value.requireValue;
    if (isEmpty != null && isEmpty(data)) {
      // Nothing cached and nothing to show: still an empty state, the offline
      // banner is rendered separately by the screen.
      return ViewEmpty<T>();
    }
    if (offline) return ViewOffline<T>(data, lastSync);
    return ViewData<T>(data);
  }
  if (value.hasError) return ViewError<T>(value.error!);
  return ViewLoading<T>();
}
