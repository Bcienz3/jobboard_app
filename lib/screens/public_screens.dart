import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import '../ui.dart';
import 'auth_screens.dart';
import 'company_screens.dart';

// ---------------- Bacheca (schermata pubblica) ----------------
class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getJobs();
    ApiService.jobsChanged.addListener(_reload);
  }

  @override
  void dispose() {
    ApiService.jobsChanged.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = ApiService.getJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bacheca annunci'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: ApiService.loggedIn,
            builder: (context, logged, _) => TextButton.icon(
              icon: Icon(logged ? Icons.business : Icons.login),
              label: Text(logged ? 'Area azienda' : 'Accesso azienda'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  logged ? const CompanyHomeScreen() : const LoginScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future.catchError((_) => <Job>[]);
        },
        child: FutureBuilder<List<Job>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('${snap.error}', textAlign: TextAlign.center),
                ),
              ]);
            }
            final jobs = snap.data!;
            if (jobs.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nessun annuncio pubblicato',
                      textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final job = jobs[i];
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(job.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${job.companyName}'
                          '${job.location != null && job.location!.isNotEmpty ? ' • ${job.location}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => JobDetailScreen(job: job)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------- Dettaglio annuncio ----------------
class JobDetailScreen extends StatelessWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio annuncio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(job.companyName, style: Theme.of(context).textTheme.titleMedium),
          if (job.location != null && job.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place, size: 18),
              const SizedBox(width: 4),
              Text(job.location!),
            ]),
          ],
          const Divider(height: 32),
          Text(job.description),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Candidati'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ApplyScreen(job: job)),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Form di candidatura ----------------
class ApplyScreen extends StatefulWidget {
  final Job job;
  const ApplyScreen({super.key, required this.job});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  PlatformFile? _cv;
  bool _sending = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.isNotEmpty && result.first.path != null) {
      setState(() => _cv = result.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cv == null) {
      showSnack(context, 'Allega il curriculum');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.apply(
        jobId: widget.job.id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        message: _message.text.trim(),
        cv: _cv!,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Candidatura inviata'),
          content: const Text('La tua candidatura è stata registrata. Grazie!'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Candidati: ${widget.job.title}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo obbligatorio';
                if (!v.contains('@')) return 'Email non valida';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Messaggio', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Allega curriculum (PDF)'),
              onPressed: _pickCv,
            ),
            if (_cv != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('File: ${_cv!.name}'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Invia candidatura'),
            ),
          ],
        ),
      ),
    );
  }
}