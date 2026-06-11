# CareConnect – AI Dementia Care Platform
## Updated Implementation Guide

This document explains every change made and how to integrate them.

---

## What Was Done

| Task | File(s) | Status |
|---|---|---|
| Questionnaire & Admin system schema | `supabase_new_schema.sql` | ✅ New |
| Caregiver patient profile form | `lib/features/caregiver/patient_profile_form_screen.dart` | ✅ New |
| Caregiver periodic questionnaire | `lib/features/caregiver/caregiver_questionnaire_screen.dart` | ✅ New |
| Admin dashboard (questions / responses / staging) | `lib/features/admin/admin_dashboard.dart` | ✅ New |
| Flask AI backend (EfficientNetB3) | `backend/app.py` | ✅ Complete |
| Remove TFLite; use HTTP API instead | `lib/services/alzheimers_model_service.dart` | ✅ Refactored |
| Doctor dashboard with probability bars | `lib/features/doctor/doctor_dashboard.dart` | ✅ Updated |
| Accessible patient dashboard | `lib/features/patient/patient_dashboard.dart` | ✅ Updated |
| Realtime alerts stream + junction RLS | `supabase_new_schema.sql` + `providers.dart` | ✅ Done |
| Caregiver–patient RLS via junction table | `supabase_new_schema.sql` | ✅ Done |
| New providers (questionnaire, profiles, stages) | `lib/services/providers.dart` | ✅ Updated |
| Admin route in main.dart | `lib/main.dart` | ✅ Updated |
| pubspec.yaml (remove tflite_flutter) | `pubspec.yaml` | ✅ Updated |

---

## Step 1 – Run the SQL Schema

1. Open **Supabase Dashboard → SQL Editor**
2. Paste and run **`supabase_new_schema.sql`**
3. Then paste and run **`supabase_care_invites.sql`** (loved-one invites & caregiver linking)

The invites script adds:

- `care_invites` table (pending email invites + invite codes)
- `link_patient_by_email` RPC (link existing patient or create invite)
- `accept_pending_care_invites` RPC (auto-link when patient signs up / logs in)
- RLS policies so caregivers can create `caregiver_patient_mapping` rows

### Original schema creates:
- `caregiver_patient_mapping` (junction table)
- `patient_profiles`
- `questionnaire_questions` (with 10 default questions pre-seeded)
- `questionnaire_responses`
- `patient_stages`
- Drops and replaces the open RLS policies on `emergency_alerts`
- Enables Supabase Realtime on `emergency_alerts`

---

## Step 2 – Start the Flask Backend

```bash
cd backend/
pip install -r requirements.txt
python app.py
```

The server starts on **http://localhost:5000**.

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Returns `{"status": "ok"}` |
| POST | `/predict` | Accepts `multipart/form-data` with field `image`, returns prediction JSON |
| GET | `/model/info` | Returns architecture info and class labels |

### Example prediction response

```json
{
  "prediction": "Non Demented",
  "confidence": 94.3,
  "all_classes": {
    "Mild Demented": 1.2,
    "Moderate Demented": 0.5,
    "Non Demented": 94.3,
    "Very Mild Demented": 4.0
  }
}
```

### Training (Important!)

The model ships with **ImageNet weights only** — it will give random predictions for MRI until you fine-tune it. To train:

1. Download the [Alzheimer's MRI dataset from Kaggle](https://www.kaggle.com/datasets/tourist55/alzheimers-dataset-4-class-of-images) (4 class, ~6400 images)
2. Run the training script (add to `backend/train.py`):

```python
from app import build_model, IMG_SIZE, CLASS_LABELS, MODEL_PATH
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping

model = build_model()

train_gen = ImageDataGenerator(
    rescale=1./255, validation_split=0.2,
    rotation_range=15, horizontal_flip=True,
    zoom_range=0.1, brightness_range=[0.85, 1.15],
)
train_data = train_gen.flow_from_directory(
    'data/train', target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=32, class_mode='categorical', subset='training')
val_data   = train_gen.flow_from_directory(
    'data/train', target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=32, class_mode='categorical', subset='validation')

model.fit(
    train_data, validation_data=val_data, epochs=30,
    callbacks=[
        ModelCheckpoint(MODEL_PATH, save_best_only=True, monitor='val_accuracy'),
        EarlyStopping(patience=5, restore_best_weights=True),
    ],
)
print("Saved to", MODEL_PATH)
```

3. Once trained, `alzheimers_efficientnet.h5` will be saved next to `app.py` and loaded automatically on next server start.

### Production deployment

For production, deploy the Flask app to a VM, Railway, or Render. Set the `FLASK_API_URL` Dart environment variable:

```
flutter run --dart-define=FLASK_API_URL=https://your-server.com
```

---

## Step 3 – Flutter Changes

### Copy files

Copy the updated files from `lib/` and replace the originals in your Flutter project.

### Remove TFLite

1. Remove `tflite_flutter: ^0.12.1` and `image: ^4.8.0` from your `pubspec.yaml` (already done in the new `pubspec.yaml`)
2. Delete the `assets/models/` folder (the `.tflite` model is gone; backend handles this now)
3. Remove the `assets/models/` entry from your old `pubspec.yaml`
4. Run `flutter pub get`

### Link Caregiver → Patient

The junction table `caregiver_patient_mapping` must be populated. You can do this via the Supabase Dashboard or add an admin UI to create mappings. The `CaregiverQuestionnaireScreen` and `PatientProfileFormScreen` both accept a `patientId` parameter which you pass from the caregiver dashboard once you list mapped patients.

### Admin role setup

Create a user in Supabase Auth, then in the `users` table set `role = 'admin'` for that user. The admin will be routed to `AdminDashboard` automatically.

---

## Architecture Overview

```
Flutter App
│
├── PatientDashboard     (accessible UI, SOS alerts, cognitive game)
├── CaregiverDashboard   → PatientProfileFormScreen
│                        → CaregiverQuestionnaireScreen
├── DoctorDashboard      → [HTTP] → Flask API → EfficientNetB3
└── AdminDashboard
    ├── Tab 1: Manage Questions (CRUD questionnaire_questions)
    ├── Tab 2: Review Responses (view submitted questionnaire_responses)
    └── Tab 3: Assign Staging (write patient_stages, mark response REVIEWED)

Supabase
├── emergency_alerts     (RLS: caregiver_patient_mapping enforced)
├── caregiver_patient_mapping
├── patient_profiles
├── questionnaire_questions
├── questionnaire_responses
└── patient_stages

Flask Backend
└── /predict             (EfficientNetB3 + CLAHE preprocessing)
```

---

## Realtime Alerts

The `activeEmergencyAlertsProvider` in `providers.dart` uses Supabase's `.stream()` which opens a WebSocket. The caregiver's screen updates **instantly** when a patient triggers an SOS — no polling needed.

RLS ensures caregivers only receive alerts for patients in their `caregiver_patient_mapping` rows.
