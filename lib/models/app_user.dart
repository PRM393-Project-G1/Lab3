/// The signed-in user, free of any Firebase type.
class AppUser {
  const AppUser({required this.uid, this.displayName, this.photoUrl});

  final String uid;
  final String? displayName;
  final String? photoUrl;
}
