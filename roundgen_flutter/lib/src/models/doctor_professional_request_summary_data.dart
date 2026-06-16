class DoctorProfessionalRequestSummaryData {
  const DoctorProfessionalRequestSummaryData({
    this.pendingTotal = 0,
    this.approvedToday = 0,
    this.rejectedToday = 0,
  });

  final int pendingTotal;
  final int approvedToday;
  final int rejectedToday;

  factory DoctorProfessionalRequestSummaryData.fromJson(Map<String, dynamic> json) {
    return DoctorProfessionalRequestSummaryData(
      pendingTotal: (json['pending_total'] as num?)?.toInt() ?? 0,
      approvedToday: (json['approved_today'] as num?)?.toInt() ?? 0,
      rejectedToday: (json['rejected_today'] as num?)?.toInt() ?? 0,
    );
  }
}
