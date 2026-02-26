import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Admin authentication modal.
///
/// Shown after the 3-second long-press gesture on the app logo.  The admin
/// enters their username and password; the [onSubmit] callback performs the
/// actual bcrypt verification via [AuthService] and returns true on success.
///
/// Returns true if login succeeded, false if the admin cancelled.
///
/// ## Usage
/// ```dart
/// final loggedIn = await showAdminLoginModal(
///   context: context,
///   onSubmit: (username, password) async {
///     final result = await ref
///         .read(authServiceProvider)
///         .loginAdmin(username, password);
///     if (result is AdminLoginSuccess) {
///       ref.read(adminSessionProvider.notifier).state = result.admin;
///       return true;
///     }
///     return false;
///   },
/// );
/// ```
Future<bool> showAdminLoginModal({
  required BuildContext context,
  required Future<bool> Function(String username, String password) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AdminLoginModal(onSubmit: onSubmit),
  );
  return result ?? false;
}

class _AdminLoginModal extends StatefulWidget {
  const _AdminLoginModal({required this.onSubmit});

  final Future<bool> Function(String username, String password) onSubmit;

  @override
  State<_AdminLoginModal> createState() => _AdminLoginModalState();
}

class _AdminLoginModalState extends State<_AdminLoginModal> {
  static const Color _crimson = Color(0xFF8B0000);
  static const Color _charcoal = Color(0xFF2C2C2C);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _usernameFocus.requestFocus());
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_rebuild)
      ..dispose();
    _passwordController
      ..removeListener(_rebuild)
      ..dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _canSubmit =>
      _usernameController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_isLoading;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.onSubmit(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid username or password.';
        _passwordController.clear();
      });
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              const Icon(Icons.admin_panel_settings_outlined,
                  color: _crimson, size: 44),
              const SizedBox(height: 12),
              Text(
                'Admin Access',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _crimson,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Wellness on Wellington',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: _charcoal.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── Username ─────────────────────────────────────────────────
              TextField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: GoogleFonts.nunito(color: _charcoal),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: _charcoal.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _crimson, width: 2),
                  ),
                ),
                style: GoogleFonts.nunito(fontSize: 16, color: _charcoal),
              ),
              const SizedBox(height: 16),

              // ── Password ─────────────────────────────────────────────────
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                maxLength: 64, // admin passwords have no upper-bound limit
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.nunito(color: _charcoal),
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: _charcoal.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _crimson, width: 2),
                  ),
                  errorText: _errorMessage,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: _charcoal.withValues(alpha: 0.5),
                    ),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: _charcoal,
                  letterSpacing: _obscure ? 4 : 1,
                ),
              ),
              const SizedBox(height: 28),

              // ── Buttons ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _charcoal.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w600,
                          color: _charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _crimson,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Login',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
