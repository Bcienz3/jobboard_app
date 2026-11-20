import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import '../ui.dart';

// ---------------- Area riservata: i miei annunci ----------------
class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getMyJobs();
  }

  void _reload() {
    setState(() {
      _future = ApiService.getMyJobs();
    });
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ApiService.companyName ?? 'Area azienda'),
        actions: [
          IconButton(
            tooltip: 'Vedi bacheca',
            icon: const Icon(Icons.storefront),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuovo annuncio'),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NewJobScreen()),
          );
          if (created == true) _reload();
        },
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
                  child: Text('Non hai ancora pubblicato annunci',
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
                    subtitle: Text('${job.applicationsCount} candidature'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ApplicationsScreen(job: job)),
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

// ---------------- Nuovo annuncio ----------------
class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.createJob(
          _title.text.trim(), _description.text.trim(), _location.text.trim());
      if (!mounted) return;
      showSnack(context, 'Annuncio pubblicato');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo annuncio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titolo *', border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Sede', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Descrizione *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
              validator: _required,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _publish,
              child: _loading
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Pubblica'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Candidature di un annuncio ----------------
class ApplicationsScreen extends StatelessWidget {
  final Job job;
  const ApplicationsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Candidature: ${job.title}')),
      body: FutureBuilder<List<Application>>(
        future: ApiService.getApplications(job.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final apps = snap.data!;
          if (apps.isEmpty) {
            return const Center(child: Text('Nessuna candidatura ricevuta'));
          }
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final a = apps[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${a.firstName} ${a.lastName}'),
                  subtitle: Text(a.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ApplicationDetailScreen(application: a)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- Dettaglio candidatura ----------------
class ApplicationDetailScreen extends StatefulWidget {
  final Application application;
  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _opening = false;

  Future<void> _openCv() async {
    setState(() => _opening = true);
    try {
      await ApiService.openCv(widget.application);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.application;
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio candidato')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Nome', a.firstName),
          _row('Cognome', a.lastName),
          _row('Email', a.email),
          _row('Telefono', a.phone),
          _row('Messaggio', a.message),
          _row('Curriculum', a.cvOriginalName),
          _row('Inviata il', a.createdAt),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _opening
                ? const SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.description),
            label: const Text('Apri curriculum'),
            onPressed: _opening ? null : _openCv,
          ),
        ],
      ),
    );
  }
}