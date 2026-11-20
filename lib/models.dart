class Job {
  final int id;
  final String title;
  final String description;
  final String? location;
  final String companyName;
  final String createdAt;
  final int applicationsCount;

  Job.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        description = j['description'],
        location = j['location'],
        companyName = j['company_name'] ?? '',
        createdAt = j['created_at'] ?? '',
        applicationsCount = j['applications_count'] ?? 0;
}

class Application {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? message;
  final String cvFile;
  final String? cvOriginalName;
  final String createdAt;

  Application.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        firstName = j['first_name'],
        lastName = j['last_name'],
        email = j['email'],
        phone = j['phone'],
        message = j['message'],
        cvFile = j['cv_file'],
        cvOriginalName = j['cv_original_name'],
        createdAt = j['created_at'] ?? '';
}