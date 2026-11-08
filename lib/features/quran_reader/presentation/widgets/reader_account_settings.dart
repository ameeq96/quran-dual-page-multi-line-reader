import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_file_export.dart';
import '../../data/services/reader_account_service.dart';
import '../controllers/quran_reader_controller.dart';

enum _AccountAction { register, login, recover, pair }

class ReaderAccountSettings extends StatefulWidget {
  const ReaderAccountSettings({super.key, required this.controller});
  final QuranReaderController controller;
  @override
  State<ReaderAccountSettings> createState() => _ReaderAccountSettingsState();
}

class _ReaderAccountSettingsState extends State<ReaderAccountSettings> {
  bool _busy = false;
  String? _message;

  Future<void> _exportBackup(BuildContext context) async {
    await exportReaderFile(fileName: 'quran_reader_before_account.json',
        contents: widget.controller.buildStateBackupJson(), mimeType: 'application/json',
        subject: tr(context, 'Quran Reader backup'), text: tr(context, 'Keep this backup before switching accounts.'));
  }

  Future<bool> _confirmReplacement(ReaderPreparedAccount prepared) async {
    return await showDialog<bool>(context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog(
      title: Text(tr(dialogContext, 'Replace local reader data?')),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(dialogContext, 'The selected backup has been checked. Connecting replaces bookmarks, notes, progress and reading settings on this device.')),
          const SizedBox(height: 12),
          Text(tr(dialogContext, 'Backup page: {page}', args: {'page': prepared.snapshot!.lastPageNumber})),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.download_outlined), label: Text(tr(dialogContext, 'Export current backup')),
            onPressed: () async {
              try { await _exportBackup(dialogContext); }
              catch (_) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(tr(dialogContext, 'Backup export failed. Try again.'))));
              }
            }),
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(dialogContext, 'Cancel'))),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(dialogContext, 'Replace and connect'))),
      ],
    )) ?? false;
  }

  Future<void> _showRecoveryKey(String key) async {
    bool visible = false;
    bool saved = false;
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (dialogContext) => PopScope(canPop: false, child: StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text(tr(context, 'Save your recovery key')),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'This key is shown once. Store it privately. Recovery replaces your password, invalidates old sessions and gives you a new key.')),
            const SizedBox(height: 16),
            SelectableText(visible ? key : '••••••••••••••••••••••••', textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: () => update(() => visible = !visible), icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                label: Text(tr(context, visible ? 'Hide key' : 'Show key'))),
              TextButton.icon(onPressed: () async {
                await Clipboard.setData(ClipboardData(text: key));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Recovery key copied. Keep your clipboard private.'))));
              }, icon: const Icon(Icons.copy_outlined), label: Text(tr(context, 'Copy key'))),
            ]),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: saved,
              onChanged: (value) => update(() => saved = value ?? false), title: Text(tr(context, 'I saved my recovery key privately.'))),
          ]))),
        actions: [FilledButton(onPressed: saved ? () => Navigator.of(dialogContext).pop() : null,
          child: Text(tr(context, 'Continue')))],
      ))));
  }

  Future<void> _openAccount(_AccountAction action) async {
    final email = TextEditingController(text: widget.controller.readerAccountEmail ?? '');
    final password = TextEditingController();
    final recovery = TextEditingController();
    final code = TextEditingController();
    bool busy = false;
    bool showPassword = false;
    String? error;
    final title = switch (action) {
      _AccountAction.register => 'Create reader account',
      _AccountAction.login => 'Sign in to reader account',
      _AccountAction.recover => 'Recover reader account',
      _AccountAction.pair => 'Connect with pairing code',
    };
    setState(() { _busy = true; _message = null; });
    try {
      final route = DialogRoute<void>(context: context, barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(builder: (context, update) => PopScope(canPop: !busy, child: AlertDialog(
          title: Text(tr(context, title)),
          content: SizedBox(width: 460, child: SingleChildScrollView(child: AutofillGroup(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, action == _AccountAction.register
                  ? 'Creating an account saves this reader backup to your configured server. Your current reader data stays on this device.'
                  : action == _AccountAction.pair
                      ? 'Paste the temporary code from the other device. It works once and expires after five minutes.'
                      : 'Your account backup will be checked before you choose whether to replace local reader data.')),
              const SizedBox(height: 16),
              if (action == _AccountAction.pair)
                TextField(controller: code, enabled: !busy, autocorrect: false, enableSuggestions: false,
                  textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr(context, 'Pairing code')))
              else ...[
                TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username], autocorrect: false,
                  textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr(context, 'Email address'))),
                const SizedBox(height: 12),
                TextField(controller: password, enabled: !busy, obscureText: !showPassword,
                  autocorrect: false, enableSuggestions: false,
                  autofillHints: [action == _AccountAction.login ? AutofillHints.password : AutofillHints.newPassword],
                  textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr(context,
                    action == _AccountAction.recover ? 'New password' : 'Password'),
                    helperText: tr(context, 'At least 12 characters; at most 72 UTF-8 bytes.'),
                    suffixIcon: IconButton(tooltip: tr(context, showPassword ? 'Hide password' : 'Show password'),
                      onPressed: busy ? null : () => update(() => showPassword = !showPassword),
                      icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
                if (action == _AccountAction.recover) ...[
                  const SizedBox(height: 12),
                  TextField(controller: recovery, enabled: !busy, obscureText: true, autocorrect: false, enableSuggestions: false,
                    textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr(context, 'Recovery key'))),
                  const SizedBox(height: 8),
                  Text(tr(context, 'Recovery uses your saved key, not an email code. Old sessions and old pairing codes will stop working.')),
                ],
              ],
              if (error != null) ...[const SizedBox(height: 12), Text(tr(context, error!), style: TextStyle(color: Theme.of(context).colorScheme.error))],
            ])))),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
            FilledButton(onPressed: busy ? null : () async {
              update(() { busy = true; error = null; });
              try {
                final prepared = await widget.controller.prepareReaderAccount(email: email.text,
                  password: password.text, register: action == _AccountAction.register,
                  recoveryKey: action == _AccountAction.recover ? recovery.text : null,
                  pairingCode: action == _AccountAction.pair ? code.text : null,
                  onRecoveryKey: (key) async { if (mounted && dialogContext.mounted) await _showRecoveryKey(key); });
                password.clear(); recovery.clear(); code.clear();
                if (!mounted || !dialogContext.mounted) { widget.controller.cancelReaderAccountOperation(); return; }
                if (!prepared.keepsCurrentData && !await _confirmReplacement(prepared)) {
                  widget.controller.cancelReaderAccountOperation();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  return;
                }
                if (!prepared.alreadyConnected) await widget.controller.adoptReaderAccount(prepared);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) setState(() => _message = 'Reader account connected. The selected backup is ready.');
              } catch (failure) {
                widget.controller.cancelReaderAccountOperation();
                if (dialogContext.mounted) update(() { busy = false; error = failure is ReaderAccountFailure
                    ? failure.message : 'Account settings could not be saved. Try again.'; });
              }
            }, child: Text(tr(context, busy ? 'Checking…' : action == _AccountAction.register ? 'Create account' : 'Continue'))),
          ],
        ))));
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      email.dispose(); password.dispose(); recovery.dispose(); code.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPairing() async {
    setState(() { _busy = true; _message = null; });
    try {
      final pairing = await widget.controller.createReaderPairingCode();
      if (!mounted) return;
      Timer? ticker;
      String? error;
      bool cancelling = false;
      try {
        await showDialog<void>(context: context, barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(builder: (context, update) {
            ticker ??= Timer.periodic(const Duration(seconds: 1), (_) { if (dialogContext.mounted) update(() {}); });
            final seconds = pairing.expiresAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 300);
            return AlertDialog(title: Text(tr(context, 'Pair another device')),
              content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr(context, 'Only share this code with your own device. Anyone with it can connect to this reader backup.')),
                const SizedBox(height: 16),
                if (!pairing.expired) ...[
                  Container(color: Colors.white, padding: const EdgeInsets.all(12),
                    child: QrImageView(data: pairing.code, size: 200, backgroundColor: Colors.white,
                      semanticsLabel: tr(context, 'Temporary pairing QR code'))),
                  const SizedBox(height: 12),
                  SelectableText(pairing.code, textDirection: TextDirection.ltr),
                  TextButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: pairing.code)); },
                    icon: const Icon(Icons.copy_outlined), label: Text(tr(context, 'Copy pairing code'))),
                  Text(tr(context, 'Expires in {seconds} seconds', args: {'seconds': seconds})),
                ] else Text(tr(context, 'Pairing code expired. Create a new one.')),
                if (error != null) Text(tr(context, error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]))),
              actions: [
                TextButton(onPressed: cancelling ? null : () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Close'))),
                if (!pairing.expired) FilledButton.tonal(onPressed: cancelling ? null : () async {
                  update(() { cancelling = true; error = null; });
                  try {
                    await widget.controller.cancelReaderPairingCode();
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  } catch (_) { if (dialogContext.mounted) update(() { cancelling = false; error = 'Pairing cancellation failed. The code still expires after five minutes.'; }); }
                }, child: Text(tr(context, 'Cancel pairing'))),
              ],
            );
          }));
      } finally { ticker?.cancel(); }
    } catch (failure) {
      if (mounted) setState(() => _message = failure is ReaderAccountFailure ? failure.message : 'Account request failed. Your local reader is unchanged.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _checkStatus() async {
    setState(() { _busy = true; _message = null; });
    try {
      await widget.controller.refreshReaderAccountStatus();
      if (mounted) setState(() => _message = widget.controller.readerAccountEmail == null ? 'This device uses a private reader backup without an account.' : 'Account connection checked.');
    } catch (failure) {
      if (mounted) setState(() => _message = failure is ReaderAccountFailure ? failure.message : 'Account server could not be reached. Try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  void dispose() {
    if (_busy) widget.controller.cancelReaderAccountOperation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.controller.readerAccountEmail;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(context, 'Account & devices'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(tr(context, email == null ? 'Keep a private backup, create an account, or connect another device.' : 'Connected account: {email}', args: {'email': email ?? ''})),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: _busy ? null : _checkStatus, child: Text(tr(context, 'Check account'))),
        FilledButton.tonal(onPressed: _busy ? null : () => _openAccount(_AccountAction.register), child: Text(tr(context, 'Create account'))),
        OutlinedButton(onPressed: _busy ? null : () => _openAccount(_AccountAction.login), child: Text(tr(context, 'Sign in'))),
        OutlinedButton(onPressed: _busy ? null : () => _openAccount(_AccountAction.recover), child: Text(tr(context, 'Recover account'))),
        OutlinedButton.icon(onPressed: _busy ? null : _showPairing, icon: const Icon(Icons.qr_code_rounded), label: Text(tr(context, 'Show pairing QR'))),
        OutlinedButton(onPressed: _busy ? null : () => _openAccount(_AccountAction.pair), child: Text(tr(context, 'Enter pairing code'))),
      ]),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr(context, _message!))),
    ]);
  }
}
