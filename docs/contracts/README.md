# Shared Firestore contract v2 — Spark, no paid Firebase backend

The customer, technician and future admin UI share project `fixme-ethiopia`. Cloud Functions and Cloud Storage are **not used**. The client adapter batches transactions, and deployed Firestore security rules validate every write on the server. Admin tools run only under a trusted project-owner Firebase CLI session. No privileged credential ships in the app.

## Identity

`users/{uid}`: name, role (`customer | technician`), approval (`incomplete | pending | approved | rejected | suspended`), profileComplete bool, createdAt, updatedAt?, profile? map of Full name/Email/City/Address. Rules fix initial customer approval to approved and technician approval to incomplete. Roles and approvals cannot be freely updated. `customers/{uid}` and `technicians/{uid}` bootstrap atomically with the matching user. Admin is exclusively the trusted Firebase Auth custom claim `admin:true`; project-owner REST credentials bypass rules for local administration.

`technicians/{uid}` contains public professional fields only: name, approval, skills string[] of catalog IDs, online bool, photoId?, rating?, approvedAt?. `technician_private/{uid}` contains profile, documents (image document IDs), submittedAt, badgeToken after trusted approval, and any genuine financial ledger data. No KYC images or full customer addresses belong in public technician records.

## Services and bookings

`service_categories/{slug}`: name, active bool, visitFee integer ETB. `service_areas/{slug}`: name, city, countryCode, active. Only trusted admin writes catalog data. Categories initially use refrigerator/electrical/ac/satellite/plumbing/tv/washing/cctv/water-pump/computer/microwave/other.

`bookings/{id}`: customerId, technicianId nullable, categoryId, issue, scheduledAt Timestamp, status, visitFee, createdAt, updatedAt, lastEventId. Optional issuePhotos string[], verifiedAt, verifiedCredentialId, verificationId, quoteId, quoteApprovedAt, approvedTotal, completedAt, checklist map.

`bookings/{id}/private/address`: customerId, address. Only the customer, assigned technician and admin can read. `bookings/{id}/booking_events/{eventId}`: actorId, status, createdAt. Append-only. Status updates and their referenced event must be atomic.

Customer creates requested booking, or assigned booking if an approved technician was explicitly chosen. Fee must equal the catalog fee. Assigned technician accepts or declines. Decline returns to searching and clears assignment. Trusted admin can assign an approved technician to requested/searching jobs.

Status flow: requested/searching → assigned → accepted → on_the_way → arrived → identity_verified → in_progress → quote_pending → in_progress → work_completed → customer_confirmed → payment_pending → completed. Customer cancellation is restricted to pre-arrival states; active work supports dispute. Work cannot start without booking-specific verification or complete without an approved quotation.

## Badge verification

`technician_credentials/{sha256(randomToken)}`: technicianId, active, issuedAt, revokedAt?. Only exact credential gets are allowed for authenticated users; listing/issuance/revocation are admin-only. A customer verification transaction reads the credential, approved technician and current booking; it creates `qr_verifications/{id}` and changes the same booking from arrived to identity_verified. Rules validate active credential ownership, customer identity, assignment, technician approval and both writes atomically. A locally decoded QR alone never grants verified status.

`qr_verifications/{id}`: bookingId, customerId, technicianId, credentialId, matched:true, createdAt. A rejected credential read or denied transition is a failed verification, never local success. Printed badges do not prove physical identity: the customer must compare the photo/person.

## Quotes and cash

`quotes/{id}`: bookingId, customerId, technicianId, visit, labor, parts, total integer ETB, description, status (`pending | approved | rejected`), createdAt, respondedAt?. Quote creation and quote_pending status are atomic. Labor/parts are bounded nonnegative integers; visit equals booking/catalog fee; total is checked server-side. Customer response and return to in_progress are atomic.

`payments/{bookingId}`: bookingId, customerId, technicianId, amount, method:cash, status (`customer_reported | settled`), createdAt, settledAt?. Customer report requires confirmed work and approved total. Assigned approved technician settlement and completed status are atomic. No gateway transaction or platform-held balance is simulated as real. Online gateway demo never writes a real settled payment.

`reviews/{bookingId}`: customerId, technicianId, rating 1–5, text, createdAt; one customer review per completed booking.

## Media, messaging, account

`private_media/{id}`: ownerId, kind (`kyc | profile | booking`), bookingId (empty for non-booking), base64 compressed JPEG (max 400,000 encoded characters), createdAt. Uploads are immutable. KYC is owner/admin readable, booking images participant readable, professional profile images authenticated-readable. Media is deliberately small to respect Spark storage quotas.

`conversations/{bookingId}`: participants exactly [customerId,technicianId], updatedAt. `messages/{id}`: senderId, text up to 2,000 chars, createdAt. Only participants may read/write. `complaints/{id}`: userId, bookingId, description, status:open, createdAt. Own user/admin read. `notifications/{id}`: userId, title/body, createdAt; admin writes. `users/{uid}/devices/{hash}`: device registration, updatedAt; owner read/write.

`customers/{uid}/addresses/{id}`: label,address,updatedAt. `favorites/{technicianUid}`: createdAt. Owner-only. `audit_logs/{id}`: trusted administration records. `payouts` is reserved; cash is already paid directly to the technician and no online disbursement is implemented.

## Deployment

Deploy only `auth`/`firestore` configurations. Never provision Functions, Storage, paid map APIs, billing accounts or payment gateways for this version. For trusted local administration use `node tools/admin.cjs` under the project owner login. Review KYC before approval. The tool uses optimistic document preconditions for approval/assignment and cryptographically random badge tokens.
