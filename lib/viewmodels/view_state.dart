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

  /// Short text for the error state, for example "Couldn't load".
  final String message;
}

final class Data<T> extends ViewState<T> {
  const Data(this.value);

  final T value;
}
