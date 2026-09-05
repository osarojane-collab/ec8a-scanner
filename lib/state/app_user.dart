/// App-level user identity. In real mode this is derived from the Supabase
/// session; in demo mode from the in-memory demo store. Keeping it app-level
/// means screens and providers never touch Supabase types directly.
class AppUser {
  final String id;
  final String email;
  final String fullName;
  const AppUser(
      {required this.id, required this.email, required this.fullName});
}
