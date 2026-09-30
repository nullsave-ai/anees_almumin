#!/usr/bin/env bash
# يولّد ملفات أندرويد ويطبّق الأذونات وإعدادات الإشعارات ثم يجلب الحزم
set -e
flutter create . --platforms=android --project-name anees_almumin --org com.anees
rm -f test/widget_test.dart
cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
if [ -f android/app/build.gradle.kts ]; then
  G=android/app/build.gradle.kts
  sed -i 's/compileOptions {/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$G"
  printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$G"
else
  G=android/app/build.gradle
  sed -i 's/compileOptions {/compileOptions {\n        coreLibraryDesugaringEnabled true/' "$G"
  printf '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n' >> "$G"
fi
flutter pub get
echo "تم. شغّل: flutter run"
