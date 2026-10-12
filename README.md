# Tracking Mobile (Flutter)

APK MVP pengganti Traccar Client berbasis Flutter. Mengirim lokasi melalui format OsmAnd HTTP ke `http://SERVER:5055/?id=...&lat=...&lon=...`.

Build dari Android Studio atau Gradle:

```bash
flutter create .
flutter pub get
flutter build apk --debug
```

Di Android, izinkan lokasi saat aplikasi berjalan dan background location bila diminta. Gunakan IP/domain yang dapat dijangkau HP, bukan `localhost`.
