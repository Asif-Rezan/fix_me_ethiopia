import 'dart:async';
import '../../../core/domain.dart';
import '../../../core/records.dart';

class DemoRepository implements ServiceRepository, RecordsRepository {
  DemoRepository() {
    _seed();
  }
  final _changes = StreamController<void>.broadcast();
  final Map<String, Map<String, Map<String, dynamic>>> store = {};
  void put(String collection, String id, Map<String, dynamic> value) {
    store.putIfAbsent(collection, () => {})[id] = value;
  }

  void _emit() => _changes.add(null);
  @override
  Stream<List<AppRecord>> watch({
    required String collection,
    String? ownerField,
    String? ownerId,
    String? documentId,
  }) async* {
    List<AppRecord> rows() => (store[collection] ?? {}).entries
        .where(
          (e) =>
              (documentId == null || e.key == documentId) &&
              (ownerField == null || e.value[ownerField] == ownerId),
        )
        .map(
          (e) => AppRecord(e.key, Map<String, dynamic>.unmodifiable(e.value)),
        )
        .toList();
    yield rows();
    yield* _changes.stream.map((_) => rows());
  }

  void _seed() {
    const categories = {
      "refrigerator": "Refrigerator Repair",
      "electrical": "Electrical Repair",
      "ac": "AC Repair",
      "satellite": "Satellite Dish",
      "plumbing": "Plumbing",
      "tv": "TV Repair",
      "washing": "Washing Machine",
      "cctv": "CCTV",
      "water-pump": "Water Pump",
      "computer": "Computer Repair",
      "microwave": "Microwave",
      "other": "Other Repairs",
    };
    for (final e in categories.entries) {
      put("service_categories", e.key, {
        "name": e.value,
        "active": true,
        "visitFee": 300,
      });
    }
    for (final name in ["Bole", "Arada", "Kirkos", "Yeka", "Nifas Silk"]) {
      put("service_areas", name, {"name": name, "active": true});
    }
    const names = [
      "Tesfaye Alemu",
      "Hana Getachew",
      "Dawit Bekele",
      "Meron Tadesse",
      "Samuel Girma",
      "Selam Abebe",
    ];
    for (var i = 0; i < names.length; i++) {
      final id = i == 0 ? "demo-technician" : "demo-tech-$i";
      put("technicians", id, {
        "name": names[i],
        "approval": "approved",
        "skills": categories.keys.toList(),
        "rating": 4.9 - i * .1,
        "completedJobs": 128 - i * 12,
        "experience": "${8 - i} years",
        "area": ["Bole", "Arada", "Kirkos"][i % 3],
        "bio":
            "Careful diagnostics, clear pricing and reliable repairs. Specialist in home appliances and maintenance.",
        "online": true,
      });
      put("users", id, {
        "name": names[i],
        "role": "technician",
        "approval": "approved",
        "email": "technician${i + 1}@example.com",
        "phone": "+251 911 000 00$i",
      });
    }
    put("users", "demo-customer", {
      "name": "Abebe Kebede",
      "role": "customer",
      "approval": "approved",
      "email": "abebe@example.com",
      "phone": "+251 911 000 100",
    });
    put("technician_private", "demo-technician", {
      "badgeToken": "DEMO-FIXME-00002",
      "name": "Tesfaye Alemu",
      "approval": "approved",
    });
    put("customers/demo-customer/addresses", "home", {
      "label": "Home",
      "address": "Bole, near Edna Mall, Building 12, Apartment 4, Addis Ababa",
    });
    put("customers/demo-customer/addresses", "work", {
      "label": "Work",
      "address": "Kirkos, Olympia Road, Office 203, Addis Ababa",
    });
    put("customers/demo-customer/favorites", "demo-technician", {
      "technicianId": "demo-technician",
      "name": names[0],
    });
    const states = [
      "on_the_way",
      "assigned",
      "quote_pending",
      "completed",
      "completed",
      "cancelled",
    ];
    const issues = [
      "Refrigerator is not cooling properly",
      "Kitchen tap leaks under the sink",
      "Washing machine stops during spin cycle",
      "Replace damaged wall sockets",
      "TV screen has no picture",
      "Annual air conditioner cleaning",
    ];
    for (var i = 0; i < states.length; i++) {
      final id = "FX-${1025 + i}";
      final category = [
        "refrigerator",
        "plumbing",
        "washing",
        "electrical",
        "tv",
        "ac",
      ][i];
      put("bookings", id, {
        "name": categories[category],
        "categoryId": category,
        "customerId": "demo-customer",
        "customerName": "Abebe Kebede",
        "technicianId": "demo-technician",
        "technicianName": names[0],
        "status": states[i],
        "issue": issues[i],
        "scheduledAt": DateTime.now().add(Duration(days: i < 3 ? i : -i)),
        "visitFee": 300,
        "approvedTotal": 1350 + i * 150,
        if (i == 2) "quoteId": "quote-$id",
        "checklist": <String, bool>{},
      });
      put("bookings/$id/private", "address", {
        "address":
            "Bole, near Edna Mall, Building 12, Apartment 4, Addis Ababa",
      });
      put("conversations/$id/messages", "1", {
        "text":
            "Hello Abebe! I have your service details. I will call when I reach the gate.",
        "senderId": "demo-technician",
        "createdAt": DateTime.now().subtract(const Duration(minutes: 12)),
      });
      put("conversations/$id/messages", "2", {
        "text": "Thank you, Tesfaye. Please use the side entrance.",
        "senderId": "demo-customer",
        "createdAt": DateTime.now().subtract(const Duration(minutes: 8)),
      });
      if (i == 3 || i == 4) {
        put("payments", "payment-$id", {
          "name": categories[category],
          "bookingId": id,
          "technicianId": "demo-technician",
          "amount": 1350 + i * 150,
          "status": "completed",
          "method": "Cash",
          "createdAt": DateTime.now().subtract(Duration(days: i)),
        });
        put("reviews", "review-$id", {
          "technicianId": "demo-technician",
          "customerName": "Abebe Kebede",
          "rating": 5,
          "text":
              "Arrived on time, explained the repair and left everything tidy.",
          "bookingId": id,
        });
      }
    }
    for (final uid in ["demo-customer", "demo-technician"]) {
      for (var i = 0; i < 3; i++) {
        put("notifications", "$uid-$i", {
          "userId": uid,
          "name": [
            "Your technician is on the way",
            "Quotation ready to review",
            "Service completed",
          ][i],
          "text": [
            "Tesfaye is heading to your Bole address.",
            "Review the itemized estimate before work continues.",
            "Your receipt is ready. Thank you for choosing FixMe!",
          ][i],
          "bookingId": "FX-${1025 + i}",
          "read": false,
          "createdAt": DateTime.now().subtract(Duration(hours: i)),
        });
      }
    }
    put('quotes', 'quote-FX-1027', {
      'description': 'Replace worn drive belt and test spin cycle',
      'visit': 300,
      'labor': 600,
      'parts': 750,
      'total': 1650,
      'status': 'pending',
    });
  }

  final _accounts = StreamController<Account?>.broadcast();
  Account? current;
  BookingStatus status = BookingStatus.requested;
  final List<Map<String, dynamic>> bookings = [];
  @override
  Stream<Account?> get accounts async* {
    yield current;
    yield* _accounts.stream;
  }

  void enter(AccountRole role) {
    current = Account(
      role == AccountRole.customer ? 'demo-customer' : 'demo-technician',
      role,
      Approval.approved,
      role == AccountRole.customer ? 'Abebe Kebede' : 'Tesfaye Alemu',
    );
    _accounts.add(current);
  }

  @override
  Future<void> signIn(String email, String password) async {
    enter(AccountRole.customer);
  }

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    AccountRole role,
  ) async {
    current = Account(
      role == AccountRole.customer ? 'demo-customer' : 'demo-technician',
      role,
      role == AccountRole.technician ? Approval.incomplete : Approval.approved,
      name,
    );
    _accounts.add(current);
  }

  @override
  Future<void> signOut() async {
    current = null;
    _accounts.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final uid = current?.uid ?? 'demo-customer';
    final bookingId = data['bookingId'] as String? ?? '';
    final row = store['bookings']?[bookingId];
    void updateStatus(String value) {
      if (row == null) throw StateError('Select a booking first.');
      row['status'] = value;
      for (final recipient in [
        row['customerId'],
        row['technicianId'],
      ].whereType<String>()) {
        put('notifications', '$bookingId-$value-$recipient', {
          'userId': recipient,
          'name': 'Booking ${value.replaceAll('_', ' ')}',
          'text': '${row['name']} · $bookingId',
          'type': 'booking',
          'bookingId': bookingId,
          'createdAt': DateTime.now(),
        });
      }
      status = BookingStatus.values.firstWhere((s) => s.wire == value);
    }

    switch (endpoint) {
      case 'createBooking':
        final id = 'DEMO-${bookings.length + 1025}';
        final category = data['categoryId'] ?? 'refrigerator';
        final tech = data['technicianId'] as String?;
        final value = {
          ...data,
          'name': store['service_categories']?[category]?['name'] ?? category,
          'customerId': uid,
          'technicianId': tech == null || tech.isEmpty
              ? 'demo-technician'
              : tech,
          'technicianName':
              store['technicians']?[tech]?['name'] ?? 'Tesfaye Alemu',
          'visitFee': 300,
          'status': 'assigned',
          'checklist': <String, bool>{},
        };
        bookings.add({...value, 'id': id});
        put('bookings', id, value);
        put('bookings/$id/private', 'address', {
          'address': data['address'] ?? 'Bole, Addis Ababa',
        });
        status = BookingStatus.requested;
        _emit();
        return {'bookingId': id};
      case 'transitionBooking':
        final next = BookingStatus.values.firstWhere(
          (s) => s.wire == data['status'],
        );
        final previous = row == null
            ? status
            : BookingStatus.values.firstWhere((s) => s.wire == row['status']);
        if (!previous.canTransitionTo(next)) {
          throw StateError('Invalid booking transition.');
        }
        if (row != null) row['status'] = next.wire;
        status = next;
      case 'acceptBooking':
        updateStatus('accepted');
      case 'rejectBooking':
        updateStatus('searching');
      case 'recordCashPayment':
        updateStatus('payment_pending');
      case 'confirmCashReceived':
        updateStatus('completed');
        put('payments', bookingId, {
          'name': row!['name'],
          'bookingId': bookingId,
          'technicianId': row['technicianId'],
          'amount': row['approvedTotal'] ?? 300,
          'method': 'Cash',
          'status': 'completed',
          'createdAt': DateTime.now(),
        });
      case 'createQuote':
        if (row == null) throw StateError('Select a booking first.');
        final total = QuotePrice(
          visit: 300,
          labor: data['labor'] as int,
          parts: data['parts'] as int,
        ).total;
        put('quotes', 'quote-$bookingId', {
          ...data,
          'visit': 300,
          'total': total,
          'status': 'pending',
        });
        row.addAll({'quoteId': 'quote-$bookingId', 'approvedTotal': total});
        updateStatus('quote_pending');
      case 'approveQuote':
        updateStatus('in_progress');
        row!['quoteApprovedAt'] = DateTime.now();
        store['quotes']?[row['quoteId']]?['status'] = 'approved';
      case 'rejectQuote':
        updateStatus('in_progress');
        store['quotes']?[row!['quoteId']]?['status'] = 'rejected';
      case 'updateWork':
        if (row == null) throw StateError('Select a booking first.');
        (row['checklist'] as Map)[data['task']] = data['done'];
      case 'markNotificationRead':
        store['notifications']?[data['notificationId']]?['readAt'] =
            DateTime.now();
      case 'markAllNotificationsRead':
        for (final row
            in store['notifications']?.values ?? <Map<String, dynamic>>[]) {
          if (row['userId'] == uid) row['readAt'] = DateTime.now();
        }
      case 'markConversationRead':
        put('conversations/$bookingId/reads', uid, {
          'value': DateTime.now().millisecondsSinceEpoch,
        });
        for (final alert
            in store['notifications']?.values ?? <Map<String, dynamic>>[]) {
          if (alert['userId'] == uid &&
              alert['bookingId'] == bookingId &&
              alert['type'] == 'chat') {
            alert['readAt'] = DateTime.now();
          }
        }
      case 'setTyping':
        if (data['typing'] == true) {
          put('conversations/$bookingId/typing', uid, {
            'value': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          store['conversations/$bookingId/typing']?.remove(uid);
        }
      case 'setChatPresence':
        put('conversations/$bookingId/presence', uid, {
          'value': data['online'] == true,
        });
      case 'sendMessage':
        if (bookingId.isEmpty) throw StateError('Select a booking first.');
        final messageId = DateTime.now().microsecondsSinceEpoch.toString();
        put('conversations/$bookingId/messages', messageId, {
          'text': data['text'],
          'senderId': uid,
          'createdAt': DateTime.now(),
        });
        for (final recipient in [
          row?['customerId'],
          row?['technicianId'],
        ].whereType<String>().where((id) => id != uid)) {
          put('notifications', 'chat-$messageId-$recipient', {
            'userId': recipient,
            'name': 'New message',
            'text': data['text'],
            'type': 'chat',
            'bookingId': bookingId,
            'createdAt': DateTime.now(),
          });
        }
      case 'saveAddress':
        put(
          'customers/$uid/addresses',
          DateTime.now().microsecondsSinceEpoch.toString(),
          data,
        );
      case 'toggleFavorite':
        if (data['favorite'] == true) {
          put('customers/$uid/favorites', data['technicianId'] as String, {
            'technicianId': data['technicianId'],
          });
        } else {
          store['customers/$uid/favorites']?.remove(data['technicianId']);
        }
      case 'submitReview':
        put('reviews', bookingId, {
          ...data,
          'customerName': current?.name ?? 'Abebe Kebede',
          'technicianId': row?['technicianId'],
        });
      case 'createComplaint':
        put('complaints', DateTime.now().microsecondsSinceEpoch.toString(), {
          ...data,
          'userId': uid,
          'status': 'open',
        });
      case 'submitTechnicianApplication':
        current = Account(
          uid,
          AccountRole.technician,
          Approval.pending,
          current?.name ?? 'Technician',
        );
        _accounts.add(current);
      case 'completeProfile':
        current = Account(
          uid,
          current?.role ?? AccountRole.customer,
          Approval.approved,
          current?.name ?? 'Abebe Kebede',
        );
        _accounts.add(current);
      case 'attachBookingPhotos':
        row?['issuePhotos'] = data['paths'];
      case 'setAvailability':
        store['technicians']?[uid]?['online'] = data['online'];
      default:
        throw UnsupportedError('Unsupported demo action: $endpoint');
    }
    _emit();
    return {'demo': true, 'ok': true};
  }

  @override
  Future<VerificationResult> verify(String bookingId, String credential) async {
    final matched = credential == 'DEMO-FIXME-00002';
    final row = store['bookings']?[bookingId];
    if (matched && row?['status'] == 'arrived') {
      row!['status'] = 'identity_verified';
      _emit();
    }
    return VerificationResult(
      matched: matched,
      bookingId: bookingId,
      technicianName: 'Tesfaye Alemu',
      credentialId: credential,
    );
  }
}
