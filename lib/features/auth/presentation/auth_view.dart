import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state.dart';
import '../../../core/domain.dart';
import 'auth_view_model.dart';

/// Authentication is live by default. Contact numbers belong to profile setup,
/// never to this email/Google authentication form.
class AuthView extends ConsumerStatefulWidget {
  const AuthView({super.key});
  @override
  ConsumerState<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends ConsumerState<AuthView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _signIn = false, _obscure = true, _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() work, {
    bool navigate = true,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
      if (mounted && navigate) {
        context.go('/screen/6');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(
      () => ref
          .read(authViewModelProvider.notifier)
          .authenticate(
            signIn: _signIn,
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: ref.read(flowProvider).role,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(flowProvider.select((s) => s.role));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Image.asset('assets/brand/logo.jpeg', height: 44),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _signIn ? 'Welcome back' : 'Create your account',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _signIn
                          ? 'Sign in to manage your services.'
                          : 'Join FixMe Ethiopia today.',
                      style: const TextStyle(color: Color(0xFF73869B)),
                    ),
                    const SizedBox(height: 24),
                    if (!_signIn) ...[
                      SegmentedButton<AccountRole>(
                        segments: const [
                          ButtonSegment(
                            value: AccountRole.customer,
                            label: Text('Customer'),
                          ),
                          ButtonSegment(
                            value: AccountRole.technician,
                            label: Text('Technician'),
                          ),
                        ],
                        selected: {role},
                        onSelectionChanged: _busy
                            ? null
                            : (selection) => ref
                                  .read(flowProvider.notifier)
                                  .role(selection.single),
                      ),
                      const SizedBox(height: 18),
                      _field(
                        'Full name',
                        _name,
                        validator: (v) => v == null || v.trim().length < 2
                            ? 'Enter your full name'
                            : null,
                        autofillHints: const [AutofillHints.name],
                      ),
                    ],
                    _field(
                      'Email address',
                      _email,
                      keyboard: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          v == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(v.trim())
                          ? 'Enter a valid email address'
                          : null,
                    ),
                    _field(
                      'Password',
                      _password,
                      obscure: _obscure,
                      autofillHints: [
                        _signIn
                            ? AutofillHints.password
                            : AutofillHints.newPassword,
                      ],
                      validator: (v) => v == null || v.isEmpty
                          ? 'Enter your password'
                          : !_signIn && v.length < 8
                          ? 'Use at least 8 characters'
                          : null,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_signIn ? 'Sign in' : 'Create account'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const ValueKey('google-sign-in'),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => ref
                                    .read(authViewModelProvider.notifier)
                                    .social(),
                              ),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                    if (Theme.of(context).platform == TargetPlatform.iOS &&
                        const bool.fromEnvironment('ENABLE_APPLE_SIGN_IN'))
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => ref
                                    .read(authViewModelProvider.notifier)
                                    .social(apple: true),
                              ),
                        child: const Text('Continue with Apple'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _signIn = !_signIn;
                              _error = null;
                            }),
                      child: Text(
                        _signIn
                            ? 'New to FixMe? Create an account'
                            : 'Already have an account? Sign in',
                      ),
                    ),
                    if (_signIn)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (_email.text.trim().isEmpty) {
                                  throw ArgumentError(
                                    'Enter your email address first.',
                                  );
                                }
                                await ref
                                    .read(authViewModelProvider.notifier)
                                    .reset(_email.text);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'If this email is registered, you’ll receive password reset instructions.',
                                      ),
                                    ),
                                  );
                                }
                              }, navigate: false),
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    List<String>? autofillHints,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          keyboardType: keyboard,
          obscureText: obscure,
          autofillHints: autofillHints,
          textInputAction: label == 'Password'
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: label == 'Password' ? (_) => _submit() : null,
          validator: validator,
          decoration: InputDecoration(
            hintText: label == 'Email address'
                ? 'you@example.com'
                : label == 'Password'
                ? 'Your password'
                : 'Your full name',
            suffixIcon: suffix,
          ),
        ),
      ],
    ),
  );
}
