/// Explicit state of a screen that loads data. Owned by its ViewModel.
sealed class ViewState<T> {
  const ViewState();
}

final class Loading<T> extends ViewState<T> {
  const Loading();
}

final class Empty<T> extends ViewState<T> {
  const Empty();
}

final class Failure<T> extends ViewState<T> {
  const Failure(this.message);

  /// The data could not be read. Every screen shows the same short text.
  const Failure.loadFailed() : message = loadFailedMessage;

  static const loadFailedMessage = "Couldn't load";

  /// Short text for the error state, for example "Couldn't load".
  final String message;
}

final class Data<T> extends ViewState<T> {
  const Data(this.value);

  final T value;
}

extension ViewStateValue<T> on ViewState<T> {
  /// The loaded value, or null while loading, empty or failed.
  T? get valueOrNull => switch (this) {
    Data(:final value) => value,
    _ => null,
  };
}

/// [Empty] when there is nothing to show, [Data] otherwise.
ViewState<List<E>> listState<E>(List<E> items) =>
    items.isEmpty ? Empty<List<E>>() : Data<List<E>>(items);
