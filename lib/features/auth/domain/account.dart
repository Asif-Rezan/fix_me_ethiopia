import 'package:flutter/foundation.dart';

enum AccountRole { customer, technician }

enum Approval { incomplete, pending, approved, rejected, suspended }

@immutable
class Account {
  const Account(this.uid, this.role, this.approval, this.name);
  final String uid, name;
  final AccountRole role;
  final Approval approval;
  int get home => role == AccountRole.customer
      ? (approval == Approval.incomplete ? 6 : 7)
      : approval == Approval.approved
      ? 30
      : approval == Approval.incomplete
      ? 26
      : 29;
}
