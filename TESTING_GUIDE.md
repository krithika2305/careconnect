# CareConnect Phase 1 & 2 Testing Guide

This guide walks you through testing all Phase 1 and Phase 2 features.

## Prerequisites

1. **Flutter Environment**: Ensure Flutter 3.44+ is installed
   ```bash
   flutter --version
   ```

2. **Emulator/Device**: Start an Android emulator or connect a device
   ```bash
   flutter devices
   ```

3. **Supabase Project**: Ensure all SQL schemas are applied:
   - `supabase_verification_schema.sql` (Phase 2 verification tables & columns)
   - `supabase_safe_setup.sql` or similar (RLS and RPC setup)
   - The `ensure_user_profile` RPC must exist and set `verification_status = 'UNVERIFIED'` for doctor/caregiver roles

## Quick Start

Run the app in debug mode:

```bash
flutter clean
flutter pub get
flutter run
```

The app will launch to the **Splash Screen** → **Welcome Screen**.

---

## Phase 1 Features (Existing Core Flows)

### 1️⃣ Patient Registration & Dashboard

**What to test**: Patient can register, see their dashboard, and manage patient-specific features.

**Steps**:
1. On **Welcome Screen**, tap **"Get Started"**
2. On **Role Selection**, tap **"Person Receiving Care"**
3. On **Register**, enter:
   - Name: `Test Patient`
   - Email: `patient@test.com`
   - Password: `Test123`
4. Tap **"Create Account"**
5. **Expected**: Redirects to **Patient Dashboard**
   - Shows patient profile, cognitive history, appointments, etc.

**Feature Coverage**:
- ✅ Patient profile setup
- ✅ Onboarding screens (goals, notifications, etc.)
- ✅ Dashboard with tabs (status, history, appointments, chat)
- ✅ Memory photos, mood logs, medication tracking

---

### 2️⃣ Caregiver Registration (Phase 1)

**What to test**: Caregiver can register but NOT yet upload verification (Phase 2 adds that).

**Steps**:
1. On **Welcome Screen**, tap **"Get Started"**
2. On **Role Selection**, tap **"Care Partner"**
3. On **Register**, enter:
   - Name: `Test Caregiver`
   - Email: `caregiver1@test.com`
   - Password: `Test123`
4. Tap **"Create Account"**
5. **Expected**: Redirects to **Caregiver Dashboard**
   - Shows caregiver controls, patient status, appointments, etc.

**Phase 1 Features**:
- ✅ Caregiver profile setup
- ✅ Dashboard with patient management
- ✅ Appointment scheduling
- ✅ Daily routines, geofencing, alerts, reminders

---

### 3️⃣ Doctor Registration (Phase 1 Registration Only)

**What to test**: Doctor can register; full verification flow is Phase 2.

**Steps**:
1. On **Welcome Screen**, tap **"Get Started"**
2. On **Role Selection**, tap **"Clinician"**
3. On **Register**, enter:
   - Name: `Test Doctor`
   - Email: `doctor@test.com`
   - Password: `Test123`
4. Tap **"Create Account"**
5. **Expected**: Redirects to **Doctor Credentials Upload Screen** (Phase 2)

---

## Phase 2 Features (New Verification Flows)

### 1️⃣ Doctor Credentials Upload (Phase 2)

**What to test**: Doctor completes license/credentials upload and enters pending verification.

**Prerequisites**:
- Register as Doctor (see Phase 1, step 3 above) or log in as an existing doctor with `verification_status = 'UNVERIFIED'`

**Steps**:
1. After **Doctor Registration**, you land on **Doctor Credentials Upload Screen**
   - Form fields for:
     - Medical License Number
     - Specialization
     - License Upload (document picker)
     - Passport Number (optional)
2. Fill form and upload a document:
   - Medical License: `LIC123456`
   - Specialization: `Neurology`
   - Upload a PDF/image file from your device
3. Tap **"Submit for Verification"**
4. **Expected Output**:
   - ✅ Document uploaded to Supabase Storage
   - ✅ Verification request created in `user_verification_requests` table
   - ✅ User's `verification_status` updated to `PENDING_REVIEW`
   - ✅ Redirects to **Pending Verification Screen**

**What to see on Pending Verification Screen**:
- Status: **"Account Pending Verification"**
- Timeline showing submission date
- Message: "Verification usually takes 1-2 business days"
- **"Check Status"** button to refresh

---

### 2️⃣ Caregiver Verification (Phase 2)

**What to test**: Caregiver provides ID and verification details.

**Prerequisites**:
- Register as Caregiver (see Phase 1, step 2 above) or log in as existing caregiver with `verification_status = 'UNVERIFIED'`

**Steps**:
1. After **Caregiver Registration**, you land on **Caregiver Verification Screen**
   - Form fields for:
     - Full Name
     - Date of Birth
     - ID Document Type (Dropdown: Passport, Driver License, National ID, etc.)
     - ID Upload
     - Background Check Consent (Checkbox)
2. Fill form and upload ID document:
   - Name: `Test Caregiver`
   - DOB: `1990-01-15`
   - ID Type: `Passport`
   - Upload a valid ID image
3. Check consent box
4. Tap **"Submit for Verification"**
5. **Expected Output**:
   - ✅ ID document uploaded to Supabase Storage
   - ✅ Verification request created
   - ✅ User's `verification_status` updated to `PENDING_REVIEW`
   - ✅ Redirects to **Pending Verification Screen**

---

### 3️⃣ Pending Verification Screen (Phase 2)

**What to test**: User in pending/rejected state sees appropriate messaging.

**Prerequisites**:
- Complete Doctor or Caregiver verification above, OR
- Manually set a user's `verification_status = 'PENDING_REVIEW'` in Supabase DB

**Steps**:
1. You arrive at **Pending Verification Screen** after upload
2. **See**:
   - Status badge: **"Account Pending Verification"** (yellow/warning color)
   - Icon and message
   - Submission date/time
   - Support contact info
   - **"Check Status"** button (refreshes status from DB)
3. Tap **"Check Status"**
   - **Expected**: Status refreshes; if still pending, same screen displays

**Rejection Scenario** (if admin marks as rejected in DB):
1. Set user's `verification_status = 'REJECTED'` in Supabase `users` table
2. Tap **"Check Status"** on Pending Verification Screen
3. **Expected**: Screen updates to show **"Verification Rejected"** with rejection reason

---

## Admin Verification Panel (Phase 2)

**What to test**: Admin can approve/reject pending verifications.

### Access Admin Dashboard

**Prerequisites**:
- Create an admin account or use existing admin with role `admin`
- Log in with admin credentials

**Steps**:
1. Register/login with role `admin`
2. You land on **Admin Dashboard**
3. Navigate to **"Verification Requests"** tab
4. **See**:
   - List of pending doctor/caregiver requests
   - Each request shows: User name, role, document links, submission date
   - Action buttons: **View Details**, **Approve**, **Reject**

### Approve a Verification Request

1. In **Verification Requests**, find a pending request
2. Tap **"View Details"** or **"Approve"**
3. **Expected**:
   - ✅ User's `verification_status` updated to `VERIFIED` in DB
   - ✅ Verification badge shows on admin dashboard

### Login with Verified User

1. Log out (from admin)
2. Log in with the doctor/caregiver you just approved
3. **Expected**:
   - ✅ **NOT** redirected to verification screen
   - ✅ Redirected to **Doctor/Caregiver Dashboard** instead

---

## Testing Checklists

### ✅ Phase 1 Checklist (Core Flows)

- [ ] Patient registers successfully → Patient Dashboard displays
- [ ] Caregiver registers successfully → Caregiver Dashboard displays
- [ ] Doctor registers successfully → Doctor Credentials Upload Screen appears (Phase 2)
- [ ] Patient can navigate all dashboard tabs (status, history, appointments, chat, etc.)
- [ ] Caregiver can manage patients, appointments, alerts
- [ ] Doctor can view patient data (after verification approved)

### ✅ Phase 2 Checklist (Verification Flows)

**Doctor Flow**:
- [ ] Doctor Credentials Upload Screen appears after registration
- [ ] Can pick and upload license document from device
- [ ] Form validates (license number, specialization required)
- [ ] Submit button works, document uploads to Supabase Storage
- [ ] Redirects to Pending Verification Screen after submit
- [ ] Pending Verification Screen shows correct status message
- [ ] "Check Status" button refreshes status from DB

**Caregiver Flow**:
- [ ] Caregiver Verification Screen appears after registration
- [ ] Can fill form (name, DOB, ID type, consent)
- [ ] Can pick and upload ID document
- [ ] Form validates before submit
- [ ] Submit button works, document uploads to Supabase Storage
- [ ] Redirects to Pending Verification Screen
- [ ] Pending Verification Screen shows correct status

**Pending Verification Flow**:
- [ ] Pending Verification Screen displays for both doctor & caregiver
- [ ] Status message is clear and supportive
- [ ] Check Status button refreshes without navigation
- [ ] After approval (in admin panel), user can log in and see dashboard
- [ ] After rejection, screen shows rejection reason

---

## Troubleshooting

### App Crashes on Doctor/Caregiver Verification Screen

**Cause**: Missing theme tokens or import issues

**Fix**:
```bash
flutter clean
flutter pub get
flutter run
```

### Document Upload Returns Error

**Cause**: Supabase Storage bucket not configured or RLS issue

**Fix**:
1. In Supabase dashboard, create storage bucket: `verifications`
2. Set RLS policy to allow authenticated users to upload
3. Re-run `flutter run`

### Pending Verification Screen Not Showing After Submit

**Cause**: `navigateAfterAuth()` not being called or async issue

**Fix**:
1. Check console logs: `flutter run -v` for errors
2. Ensure `ref.invalidate(userProfileProvider)` is called in registration
3. Check Supabase DB: confirm `verification_status` is set to `PENDING_REVIEW`

### User Not Redirected to Verification Screen on Login

**Cause**: `verification_status` not loaded correctly or `authRedirect()` logic issue

**Fix**:
1. In Supabase SQL Editor, verify user row has `verification_status` column set
2. Confirm `authRedirect()` in `lib/services/auth_navigation.dart` includes verification checks
3. Check user metadata: ensure `role` is set in auth metadata

---

## Database Setup (For Reference)

If verification tables don't exist, apply this SQL in Supabase:

```sql
-- Already in supabase_verification_schema.sql
-- Columns added to users table:
--   - verification_status (UNVERIFIED, PENDING_REVIEW, VERIFIED, REJECTED)
--   - account_status (ACTIVE, PENDING, SUSPENDED)
--   - verification_requested_at
--   - verification_rejected_reason

-- Tables:
--   - user_verification_requests (stores doctor/caregiver submissions)
--   - caregiver_verification (stores caregiver-specific info)
```

---

## Next Steps After Testing

1. **Customization**: Adjust messaging, colors, form fields as needed
2. **Admin Approval Workflow**: Test with actual admin users approving/rejecting
3. **Email Notifications**: Set up Firebase Cloud Functions or Supabase Edge Functions to email users on approval/rejection
4. **Production Deployment**: Use `flutter build apk` or `flutter build ios` once all flows verified

---

**Happy Testing! 🎉**
