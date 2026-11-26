import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _server = TextEditingController();
  bool _remember = true;
  bool _showPass = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.read(context).settings;
    _user.text = s.username;
    _server.text = s.apiUrl;
    _remember = s.remember;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppScope.read(context);
    FocusScope.of(context).unfocus();
    if (_server.text.trim().isEmpty) {
      s.error = 'Enter your server address (the MonitorMyInverter gateway you run).';
      setState(() {});
      return;
    }
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      s.error = 'Enter your username and password.';
      setState(() {});
      return;
    }
    await s.setApiUrl(_server.text);
    await s.login(_user.text.trim(), _pass.text, _remember);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: C.battery.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt, color: C.battery, size: 30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pi Q6 Monitor',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Live battery, solar, load and grid power from your inverter.',
                      textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13.5)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'your-gateway.example.com',
                      helperText: 'Your MonitorMyInverter gateway. Saved on this phone only.',
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _user,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: !_showPass,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _showPass ? 'Hide password' : 'Show password',
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    title: const Text('Stay signed in', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Saves the password securely on this phone to reconnect automatically',
                        style: TextStyle(fontSize: 12, color: C.faint)),
                  ),
                  if (s.error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(s.error!, style: const TextStyle(color: C.danger, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: s.loggingIn ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: C.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: s.loggingIn
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Sign in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  if (s.loggingIn)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('The server may take up to a minute to wake up.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.faint)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
