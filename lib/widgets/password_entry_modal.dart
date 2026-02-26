import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal dialog that prompts an employee to enter their password.
///
/// Used for both clock-in and clock-out actions.
///
/// ## Usage
/// ```dart
/// final result = await showPasswordEntryModal(
///   context: context,
///   employeeName: 'Alice',
///   action: PasswordAction.clockIn,
///   onSubmit: (password) async {
///     final result = await ref.read(authServiceProvider).clockIn(id, password);
///     return result is ClockInSuccess || result is ClockInRequiresPasswordSetup;
///   },
/// );
/// ```
///
/// The [onSubmit] callback receives the raw password and must return a
/// [Future<bool>] — true means auth succeeded (modal closes), false means
/// auth failed (modal shows an inline error so the employee can retry).
///
/// Returns true if the action completed successfully, false if the employee
/// cancelled.

enum PasswordAction { clockIn, clockOut }

Future<bool> showPasswordEntryModal({
  required BuildContext context,
  required String employeeName,
  required PasswordAction action,
  required Future<bool> Function(String password) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // must explicitly cancel or confirm
    builder: (_) => _PasswordEntryModal(
      employeeName: employeeName,
      action: action,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _PasswordEntryModal extends StatefulWidget {
  const _PasswordEntryModal({
    required this.employeeName,
    required this.action,
    required this.onSubmit,
  });

  final String employeeName;
  final PasswordAction action;
  final Future<bool> Function(String password) onSubmit;

  @override
  State<_PasswordEntryModal> createState() => _PasswordEntryModalState();
}

class _PasswordEntryModalState extends State<_PasswordEntryModal> {
  static const Color _crimson = Color(0xFF8B0000);
  static const Color _charcoal = Color(0xFF2C2C2C);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-focus the password field when the modal opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _title =>
      widget.action == PasswordAction.clockIn ? 'Clock In' : 'Clock Out';

  String get _actionLabel =>
      widget.action == PasswordAction.clockIn ? 'Clock In' : 'Clock Out';

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.onSubmit(password);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect password. Please try again.';
        _controller.clear();
      });
      _focusNode.requestFocus();
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
              // ── Header ────────────────────────────────────────────────
              Text(
                _title,
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _crimson,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.employeeName,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── Password field ────────────────────────────────────────
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                obscureText: _obscure,
                maxLength: 12,
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.nunito(color: _charcoal),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _crimson, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: _charcoal.withValues(alpha: 0.6),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                  errorText: _errorMessage,
                ),
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: _charcoal,
                  letterSpacing: _obscure ? 4 : 1,
                ),
              ),
              const SizedBox(height: 28),

              // ── Action buttons ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(false),
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
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        final canSubmit =
                            _controller.text.isNotEmpty && !_isLoading;
                        return FilledButton(
                          onPressed: canSubmit ? _submit : null,
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
                                  _actionLabel,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        );
                      },
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
