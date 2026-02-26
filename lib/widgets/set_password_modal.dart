import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/password_utils.dart';

/// Mandatory first-time password setup modal.
///
/// Shown immediately after an employee successfully enters "123456" on their
/// first clock-in.  The employee **cannot dismiss** this modal — tapping the
/// system back button, tapping outside the dialog, and the Android back
/// gesture are all suppressed via [PopScope].
///
/// The modal enforces:
/// - Both fields must match.
/// - Password must be [PasswordUtils.minPasswordLength]–[PasswordUtils.maxPasswordLength] characters.
/// - The new password must NOT be the same as the default ("123456").
///
/// Returns the validated new password as a [String].  The caller is
/// responsible for hashing and persisting it via [AuthService.completeClockInWithSetup].
///
/// ## Usage
/// ```dart
/// final newPassword = await showSetPasswordModal(
///   context: context,
///   employeeName: 'Alice',
/// );
/// // newPassword is never null — the employee cannot cancel.
/// ```
Future<String> showSetPasswordModal({
  required BuildContext context,
  required String employeeName,
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false, // PopScope handles this inside the widget
    builder: (_) => _SetPasswordModal(employeeName: employeeName),
  );
  // result is non-null because the modal cannot be dismissed without submitting.
  return result!;
}

class _SetPasswordModal extends StatefulWidget {
  const _SetPasswordModal({required this.employeeName});

  final String employeeName;

  @override
  State<_SetPasswordModal> createState() => _SetPasswordModalState();
}

class _SetPasswordModalState extends State<_SetPasswordModal> {
  static const Color _crimson = Color(0xFF8B0000);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _amber = Color(0xFFB45309); // for warning text

  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newFocus = FocusNode();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_rebuild);
    _confirmController.addListener(_rebuild);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _newFocus.requestFocus());
  }

  @override
  void dispose() {
    _newPasswordController
      ..removeListener(_rebuild)
      ..dispose();
    _confirmController
      ..removeListener(_rebuild)
      ..dispose();
    _newFocus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── Validation ───────────────────────────────────────────────────────────

  String get _newPassword => _newPasswordController.text;
  String get _confirmPassword => _confirmController.text;

  bool get _lengthOk => PasswordUtils.isValidLength(_newPassword);
  bool get _notDefault => _newPassword != PasswordUtils.defaultPassword;
  bool get _matches =>
      _confirmPassword.isNotEmpty && _newPassword == _confirmPassword;
  bool get _canSubmit =>
      _lengthOk && _notDefault && _matches && !_isLoading;

  /// Inline hint shown beneath the new-password field.
  String? get _newPasswordHint {
    if (_newPassword.isEmpty) return null;
    if (!_notDefault) return 'Cannot reuse the default password.';
    if (!_lengthOk) {
      return 'Must be ${PasswordUtils.minPasswordLength}–'
          '${PasswordUtils.maxPasswordLength} characters.';
    }
    return null;
  }

  /// Inline hint shown beneath the confirm field.
  String? get _confirmHint {
    if (_confirmPassword.isEmpty) return null;
    if (!_matches) return 'Passwords do not match.';
    return null;
  }

  void _submit() {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    Navigator.of(context).pop(_newPassword);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block all attempts to dismiss — this modal is mandatory.
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                const Icon(Icons.lock_outline_rounded,
                    color: _crimson, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Create Your Password',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _crimson,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome, ${widget.employeeName}!\n'
                  'Please set a personal password before clocking in.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: _charcoal.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ── New password field ───────────────────────────────────
                TextField(
                  controller: _newPasswordController,
                  focusNode: _newFocus,
                  obscureText: _obscureNew,
                  maxLength: PasswordUtils.maxPasswordLength,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    label: 'New Password',
                    errorText: _newPasswordHint,
                    obscure: _obscureNew,
                    onToggleObscure: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                  style: _fieldTextStyle(),
                ),
                const SizedBox(height: 16),

                // ── Confirm password field ───────────────────────────────
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  maxLength: PasswordUtils.maxPasswordLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _fieldDecoration(
                    label: 'Confirm Password',
                    errorText: _confirmHint,
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  style: _fieldTextStyle(),
                ),
                const SizedBox(height: 8),

                // ── Mandatory notice ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14,
                        color: _amber.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text(
                      'This step cannot be skipped.',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: _amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Confirm button (no cancel) ───────────────────────────
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _crimson,
                    disabledBackgroundColor:
                        _crimson.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Set Password & Clock In',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String? errorText,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(color: _charcoal),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _crimson, width: 2),
      ),
      errorText: errorText,
      errorStyle: GoogleFonts.nunito(color: Colors.red.shade700),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: _charcoal.withValues(alpha: 0.5),
        ),
        onPressed: onToggleObscure,
        tooltip: obscure ? 'Show password' : 'Hide password',
      ),
    );
  }

  TextStyle _fieldTextStyle() => GoogleFonts.nunito(
        fontSize: 16,
        color: _charcoal,
      );
}
