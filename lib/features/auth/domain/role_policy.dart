import 'account.dart';

String? roleRedirect({
  required int screen,
  required Account? account,
  bool loading = false,
}) {
  if (loading) {
    return screen > 6 ? '/screen/1' : null;
  }
  if (account == null) {
    return screen > 6 ? '/screen/3' : null;
  }
  if (account.approval == Approval.suspended ||
      account.approval == Approval.rejected) {
    return screen == 29 ? null : '/screen/29';
  }
  if (account.role == AccountRole.customer) {
    if (account.approval == Approval.incomplete && screen > 6) {
      return '/screen/6';
    }
    if (screen >= 26 && screen <= 43) {
      return '/screen/7';
    }
  } else {
    if (account.approval != Approval.approved && screen >= 30 && screen <= 43) {
      return '/screen/${account.home}';
    }
    if (screen >= 7 && screen <= 25) {
      return '/screen/${account.home}';
    }
  }
  return null;
}
