# OVRLD

Log kg × reps, beat last time, plan the week. A progressive-overload gym
tracker with kinetic-type design, built in Flutter.

- `apps/ovrld` - the app
- `packages/ovrld_core` - pure-Dart maths: units, double progression, Epley
  e1RM, personal records, pace, Monday-first weeks
- `docs/IPHONE.md` - **trying it on an iPhone** before it is in the App Store

```sh
flutter pub get                       # at the repo root (pub workspace)
cd apps/ovrld && flutter run          # Android or iPhone
flutter test                          # app tests
cd ../../packages/ovrld_core && dart test
```

Android release builds are signed with a key kept outside this repo
(`android/key.properties`, gitignored); without it they fall back to the debug key.
