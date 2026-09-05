DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class DashboardCounts {
  DashboardCounts({
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.approved,
    required this.revision,
    required this.open,
    required this.overdue,
  });

  final int assigned, inProgress, completed, approved, revision, open, overdue;

  int get total => assigned + inProgress + completed + approved + revision;

  factory DashboardCounts.fromJson(Map<String, dynamic> j) => DashboardCounts(
    assigned: (j['assigned'] as num?)?.toInt() ?? 0,
    inProgress: (j['in_progress'] as num?)?.toInt() ?? 0,
    completed: (j['completed'] as num?)?.toInt() ?? 0,
    approved: (j['approved'] as num?)?.toInt() ?? 0,
    revision: (j['revision'] as num?)?.toInt() ?? 0,
    open: (j['open'] as num?)?.toInt() ?? 0,
    overdue: (j['overdue'] as num?)?.toInt() ?? 0,
  );
}

class AssigneeStat {
  AssigneeStat({
    required this.assigneeId,
    required this.assignee,
    required this.total,
    required this.approved,
    required this.overdue,
  });

  final int? assigneeId;
  final String? assignee;
  final int total, approved, overdue;

  double get progress => total == 0 ? 0 : approved / total;

  factory AssigneeStat.fromJson(Map<String, dynamic> j) => AssigneeStat(
    assigneeId: (j['assignee_id'] as num?)?.toInt(),
    assignee: j['assignee'] as String?,
    total: (j['total'] as num?)?.toInt() ?? 0,
    approved: (j['approved'] as num?)?.toInt() ?? 0,
    overdue: (j['overdue'] as num?)?.toInt() ?? 0,
  );
}

class DashboardSummary {
  DashboardSummary({
    required this.counts,
    required this.completionRate,
    required this.createdInPeriod,
    required this.approvedInPeriod,
    required this.perAssignee,
  });

  final DashboardCounts counts;
  final double? completionRate;
  final int createdInPeriod;
  final int approvedInPeriod;
  final List<AssigneeStat> perAssignee;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    counts: DashboardCounts.fromJson(
      j['counts'] as Map<String, dynamic>? ?? const {},
    ),
    completionRate: (j['completion_rate'] as num?)?.toDouble(),
    createdInPeriod: (j['created_in_period'] as num?)?.toInt() ?? 0,
    approvedInPeriod: (j['approved_in_period'] as num?)?.toInt() ?? 0,
    perAssignee: (j['per_assignee'] as List? ?? const [])
        .map((e) => AssigneeStat.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ActivityEvent {
  ActivityEvent({
    required this.id,
    this.taskId,
    this.taskTitle,
    this.oldStatus,
    required this.newStatus,
    this.note,
    this.actor,
    this.at,
  });

  final int id;
  final int? taskId;
  final String? taskTitle;
  final String? oldStatus;
  final String newStatus;
  final String? note;
  final String? actor;
  final DateTime? at;

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
    id: (j['id'] as num).toInt(),
    taskId: (j['task_id'] as num?)?.toInt(),
    taskTitle: j['task_title'] as String?,
    oldStatus: j['old_status'] as String?,
    newStatus: j['new_status'] as String? ?? '',
    note: j['note'] as String?,
    actor: j['actor'] as String?,
    at: _date(j['at']),
  );
}
