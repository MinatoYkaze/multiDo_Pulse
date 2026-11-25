import 'json_helpers.dart';

enum Priority {
  low,
  medium,
  high,
  urgent;

  String get label => name.toUpperCase();
  String toJson() => name;
  static Priority fromJson(dynamic v) =>
      enumByName(Priority.values, v, Priority.medium);
}

enum Role {
  owner,
  admin,
  member;

  bool get canManageMembers => this == owner || this == admin;
  bool get isOwner => this == owner;
  String toJson() => name;
  static Role fromJson(dynamic v) => enumByName(Role.values, v, Role.member);
}

enum InvitationStatus {
  pending,
  accepted,
  rejected,
  expired;

  String toJson() => name;
  static InvitationStatus fromJson(dynamic v) {
    if (v == 'declined') return InvitationStatus.rejected;
    return enumByName(InvitationStatus.values, v, InvitationStatus.pending);
  }
}
