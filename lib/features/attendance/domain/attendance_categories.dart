class AttendanceCategory {
  const AttendanceCategory(this.value, this.label, this.parent);
  final String value;
  final String label;
  final String parent;
}

const attendanceTypes = <AttendanceCategory>[
  AttendanceCategory('', 'All', ''),
  AttendanceCategory('visitor', 'Visitors', ''),
  AttendanceCategory('buyer', 'Buyers', ''),
  AttendanceCategory('exhibitor', 'Exhibitors', ''),
];

const attendanceSubTypes = <AttendanceCategory>[
  AttendanceCategory('general-visitor', 'General', 'visitor'),
  AttendanceCategory('corporate-visitor', 'Corporate', 'visitor'),
  AttendanceCategory('group-visitor-member', 'Group', 'visitor'),
  AttendanceCategory('health-camp-visitor', 'Health Camp', 'visitor'),
  AttendanceCategory('buyer', 'Domestic Buyer', 'buyer'),
  AttendanceCategory('international-buyer', 'International Buyer', 'buyer'),
  AttendanceCategory('exhibitor', 'Exhibitor', 'exhibitor'),
  AttendanceCategory('seller', 'Seller', 'exhibitor'),
];

List<AttendanceCategory> subTypesFor(String parent) =>
    attendanceSubTypes.where((item) => item.parent == parent).toList();

String attendanceLabel(String value) {
  for (final item in [...attendanceTypes, ...attendanceSubTypes]) {
    if (item.value == value) return item.label;
  }
  return value.replaceAll('-', ' ');
}
