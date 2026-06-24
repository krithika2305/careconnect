# Quick Testing Commands

## Run the App

```bash
# Clean build and run
flutter clean
flutter pub get
flutter run

# Or verbose mode for debugging
flutter run -v

# On specific device
flutter run -d <device_id>
```

## View Logs

```bash
# Real-time logs
flutter logs

# Grep for specific errors
flutter logs | grep -i "error"
```

## Common Testing Scenarios

### Scenario 1: Test Patient Flow (Phase 1)
```
1. Launch app
2. Welcome → "Get Started"
3. Role Selection → "Person Receiving Care"
4. Register: patient@test.com / Test123
5. Should see Patient Dashboard
```

### Scenario 2: Test Doctor Verification (Phase 2)
```
1. Launch app
2. Welcome → "Get Started"
3. Role Selection → "Clinician"
4. Register: doctor@test.com / Test123
5. Should see Doctor Credentials Upload Screen
6. Upload a file (any PDF/image)
7. Should redirect to Pending Verification Screen
```

### Scenario 3: Test Caregiver Verification (Phase 2)
```
1. Launch app
2. Welcome → "Get Started"
3. Role Selection → "Care Partner"
4. Register: caregiver@test.com / Test123
5. Should see Caregiver Verification Screen
6. Fill form + upload ID
7. Should redirect to Pending Verification Screen
```

### Scenario 4: Test Login with Pending Verification (Phase 2)
```
1. Logout (if logged in)
2. Login: doctor@test.com / Test123
3. Should redirect to Pending Verification Screen (not Dashboard)
4. Can tap "Check Status" to refresh
```

## Database Checks

In Supabase SQL Editor:

```sql
-- Check user was created with correct fields
SELECT id, email, role, verification_status, account_status 
FROM users 
WHERE email = 'doctor@test.com';

-- Check verification request was created
SELECT * FROM user_verification_requests 
WHERE user_id = '<user_id>';

-- Check uploaded documents
SELECT * FROM caregiver_verification 
WHERE user_id = '<user_id>';
```

## Simulate Admin Approval

To test approval workflow in Supabase SQL Editor:

```sql
-- Approve a doctor
UPDATE users 
SET verification_status = 'VERIFIED' 
WHERE email = 'doctor@test.com';

-- Then: Logout and login as doctor
-- Expected: Should redirect to Doctor Dashboard instead of verification screen
```

## Troubleshoot Build Errors

```bash
# If build fails
flutter clean
flutter pub get
flutter pub upgrade

# Run analysis
flutter analyze

# Check lint issues
dart fix --dry-run
```

## Check Device/Emulator

```bash
# List available devices
flutter devices

# Start emulator
emulator -avd <emulator_name>

# Kill all emulators
killall java
```
