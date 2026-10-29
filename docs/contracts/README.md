# FIX ME ETHIOPIA shared contract v1

The Flutter customer/technician app and separately hosted admin dashboard use **one** Firebase project: `fixme-ethiopia`. The admin UI must use the callables here. Do not create another collection schema or write privileged state directly from an admin browser.

## Identity and authorization

Firebase Auth UID is the document ID for `users`, `customers`, `technicians`, and `technician_private`. `users` contains name, role (`customer | technician`), approval (`incomplete | pending | approved | rejected | suspended`), createdAt and optional profile map. Admin is exclusively a trusted custom claim `admin: true`, issued with Admin SDK outside the client. Neither UI may set admin claims. Technician approval, credentials, quotes, prices, and money status are server controlled. Timestamps in Firestore are Timestamp values; callable schedules use ISO 8601 UTC.

## Collections

- `customers/{uid}`: name, createdAt. Private account view.
- `technicians/{uid}`: name, approval, skills string[], photoUrl?, online bool, rating?, createdAt. Public professional data only; no KYC or private customer addresses.
- `technician_private/{uid}`: profile map, documents string[] of Storage paths, submittedAt, badgeToken?, availableBalance integer. Owner/admin only. Badge is issued only on approval.
- `service_categories/{slug}`: name, active bool, visitFee nonnegative integer ETB. Admin must configure valid categories before accepting bookings. `refrigerator` is the initial client category key.
- `service_areas/{slug}`: name, active bool, city, countryCode (`ET`).
- `bookings/{autoId}`: customerId, technicianId nullable, categoryId, issue, scheduledAt, status, visitFee, createdAt; optional quoteId, quoteApprovedAt, approvedTotal, verifiedAt, verifiedCredentialId, completedAt.
- `bookings/{id}/private/address`: customerId, address. Only booking participants/admin can read. Unassigned technicians cannot query bookings or see addresses.
- `bookings/{id}/booking_events/{autoId}`: actorId, status, createdAt. Append-only, server-written.
- `technician_credentials/{sha256(token)}`: technicianId, active bool, issuedAt. No direct client reads. Raw random badge token is stored privately for its owner. Revocation sets active false through trusted backend administration.
- `qr_verifications/{autoId}`: bookingId, customerId, technicianId, credentialId, matched bool, createdAt.
- `conversations/{bookingId}`: participants UID[], updatedAt; `messages/{autoId}`: senderId, text, createdAt.
- `quotes/{autoId}`: bookingId, customerId, technicianId, visit, labor, parts, total (integer ETB), description, status, createdAt, approvedAt?.
- `payments/{bookingId}`: bookingId, customerId, technicianId, amount, method (`cash`), status (`customer_reported | settled`), createdAt, settledAt?. Stable ID prevents duplicate settlement.
- `payouts/{sha256(uid:idempotencyKey)}`: technicianId, amount integer ETB, status (`requested`), createdAt. Transaction reserves balance once. Actual disbursement requires a configured financial provider and a trusted settlement workflow.
- `reviews/{bookingId}`: customerId, technicianId, rating integer 1–5, text, createdAt. One review per completed booking.
- `notifications/{autoId}`: userId, title, body, createdAt, readAt?.
- `users/{uid}/devices/{sha256(token)}`: token, updatedAt. Server-only push registration.
- `complaints/{autoId}`: userId, bookingId?, description, status (`open`), createdAt.
- `audit_logs/{autoId}`: action, actorId, technicianId?, createdAt. Admin-readable, server-written.

## Callable API (us-central1)

All endpoints require Firebase authentication and App Check. Admin callables additionally require the admin custom claim. Errors use `unauthenticated`, `permission-denied`, `invalid-argument`, and `failed-precondition`. The caller must surface errors; never simulate success after a failed call.

- `createProfile({name,role}) -> {ok}`: creates once; only customer/technician accepted. Customer approved; technician incomplete.
- `completeProfile({profile}) -> {ok}`: whitelists user-editable name/email/city/address fields. Does not alter role or approval.
- `createBooking({categoryId,issue,address,scheduledAt,slot?}) -> {bookingId}`: approved customer; fee read from category, never from client. Initial status requested.
- `assignTechnician({bookingId,technicianId}) -> {ok}`: admin; only approved technicians, requested/searching bookings.
- `rejectBooking({bookingId}) -> {ok}`: assigned technician declines an assigned request; clears assignment and returns to searching.
- `attachBookingPhotos({bookingId,paths}) -> {ok}`: owner, verifies owned Storage objects before adding issue photo paths.
- `acceptBooking({bookingId}) -> {ok}`: assigned approved technician only.
- `transitionBooking({bookingId,status}) -> {ok}`: actor-specific state graph; cannot set payment or verified status.
- `verifyTechnician({bookingId,credential}) -> {matched,credentialId,name,photoUrl}`: assigned customer, arrived booking; active credential matches assigned approved technician. Comparison and booking transition are atomic. Static badges identify a credential and cannot prove physical identity. Customer must compare photo and person.
- `submitTechnicianApplication({skills,profile,documents}) -> {ok}`: own incomplete/rejected application; at least two owned, uploaded KYC images. Sets pending.
- `approveTechnician({technicianId}) -> {ok}`: admin; pending application; generates a cryptographically random credential.
- `setAvailability({online}) -> {ok}`: approved technician.
- `createQuote({bookingId,labor,parts,description}) -> {quoteId}`: assigned verified technician; server totals validated integer prices with catalog fee.
- `approveQuote({bookingId}) -> {ok}`: customer only; approved total becomes immutable on booking.
- `recordCashPayment({bookingId}) -> {ok,status:payment_pending}`: customer reports cash after confirming work. **Does not issue a paid receipt.**
- `confirmCashReceived({bookingId}) -> {ok}`: assigned approved technician confirms cash and completes booking atomically. Cash is paid directly to technician; it does not create platform-held withdrawable funds.
- `requestPayout({amount,idempotencyKey}) -> {ok}`: owner; transaction verifies and reserves withdrawable balance. No provider transfer is claimed.
- `sendMessage({bookingId,text}) -> {ok}`: participant only, max 2,000 chars.
- `registerPushToken({token}) -> {ok}`: own device registration.
- `submitReview({bookingId,rating,text}) -> {ok}`: customer of completed booking, once.
- `createComplaint({bookingId?,description}) -> {ticketId}`: authenticated support request.

## State machine

requested → searching → assigned → accepted → on_the_way → arrived → identity_verified → in_progress → quote_pending → in_progress → work_completed → customer_confirmed → payment_pending → completed.

Admin assignment can move requested directly to assigned. Starting work requires verifiedAt. Completing work requires an approved quote. Customer cancels only requested/searching/assigned/accepted states. Active service can enter disputed. Terminal states cannot reopen. Client enum and backend policy must be changed together.

## Storage

KYC: `kyc/{uid}/{timestamp}.jpg`, owner/admin read only. Booking photos: `bookings/{bookingId}/{uid}/{timestamp}.jpg`, participant reads and owner creates. Profile photos: `profiles/{uid}/{file}`, authenticated reads. Only JPEG, PNG or WebP images under 10 MB; KYC/booking uploads cannot overwrite existing files.

## Admin deployment responsibilities

Register genuine service categories/fees and service areas; create an admin custom claim from a trusted Admin SDK environment; review KYC before calling approveTechnician; assign technicians; configure credential revocation and payout reconciliation. This repository includes the callable backend, not an additional admin website. No admin service account or private key belongs in Flutter, Hosting JS, or version control.
