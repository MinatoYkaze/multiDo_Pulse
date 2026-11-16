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
  declined,
  expired;

  String toJson() => name;
  static InvitationStatus fromJson(dynamic v) =>
      enumByName(InvitationStatus.values, v, InvitationStatus.pending);
}
