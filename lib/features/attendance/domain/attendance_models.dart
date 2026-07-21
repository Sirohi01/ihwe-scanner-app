class PersonProfile {
  PersonProfile.fromJson(Map<String, dynamic> json)
      : id = json['subjectId']?.toString() ?? '',
        type = json['subjectType']?.toString() ?? '',
        subType = json['subjectSubType']?.toString() ?? '',
        registrationId = json['registrationId']?.toString() ?? '',
        name = json['name']?.toString() ?? '',
        company = json['company']?.toString() ?? '',
        designation = json['designation']?.toString() ?? '',
        email = json['email']?.toString() ?? '',
        mobile = json['mobile']?.toString() ?? '',
        country = json['country']?.toString() ?? '',
        photoUrl = json['photoUrl']?.toString() ?? '',
        photoKind = json['photoKind']?.toString() ?? 'person',
        status = json['status']?.toString() ?? '';
  final String id,
      type,
      subType,
      registrationId,
      name,
      company,
      designation,
      email,
      mobile,
      country,
      photoUrl,
      photoKind,
      status;
}

class ScanResult {
  ScanResult.fromJson(Map<String, dynamic> json)
      : person =
            PersonProfile.fromJson(Map<String, dynamic>.from(json['person'])),
        days = List<String>.from(json['days'] ?? []),
        attendedDays = (json['attendance'] as List? ?? [])
            .map((e) => e['eventDay'].toString())
            .toSet();
  final PersonProfile person;
  final List<String> days;
  final Set<String> attendedDays;
}
