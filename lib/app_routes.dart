/// Every location the app navigates to.
///
/// The router builds its patterns from the same functions, for example
/// `overview(':id')`, so a link and its route cannot drift apart.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const connect = '/connect';
  static const analyze = '/analyze';
  static const history = '/history';
  static const profile = '/profile';
  static const notifications = '/notifications';

  /// Connect, opened from Profile.
  static const serverSettings = '$profile/server';

  /// The bottom navigation tabs, in order.
  static const tabs = [analyze, history, profile];

  /// Analyze with the text another app shared, such as an arXiv link.
  static String analyzeShared(String text) =>
      Uri(path: analyze, queryParameters: {'shared': text}).toString();

  static String overview(String id) => '/analyses/$id';

  static String progress(String id) => '${overview(id)}/progress';

  /// Overview when a finished result exists, otherwise the progress screen.
  static String analysis(String id, {required bool done}) =>
      done ? overview(id) : progress(id);

  static String topics(String id) => '${overview(id)}/topics';

  static String topic(String id, String topicId) => '${topics(id)}/$topicId';

  static String graph(String id) => '${overview(id)}/graph';

  /// [filter] is a key that `ReferenceFilter.parse` reads.
  static String references(String id, {String? filter}) => filter == null
      ? '${overview(id)}/references'
      : '${overview(id)}/references?filter=$filter';

  static String reference(String id, String refId) =>
      '${overview(id)}/references/$refId';
}
