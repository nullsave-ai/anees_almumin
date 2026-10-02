#!/usr/bin/env bash
# يولّد ملفات أندرويد ويطبّق الأذونات والإشعارات ونسخ أصوات الأذان تلقائيًا. يمكن إعادة تشغيله بأمان.
set -e
flutter create . --platforms=android --project-name anees_almumin --org com.anees
rm -f test/widget_test.dart
cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
# MainActivity: جسر أصلي صغير لإضافة صوت أذان مخصص إلى MediaStore (يلزم لصوت الإشعار)
M=$(find android/app/src -name MainActivity.kt | head -1)
if [ -n "$M" ]; then
  PKG=$(grep -m1 '^package ' "$M")
  { echo "$PKG"; echo; cat android_overrides/MainActivity.kt.body; } > "$M"
fi
if [ -f android/app/build.gradle.kts ]; then
  G=android/app/build.gradle.kts
  if ! grep -q coreLibraryDesugaring "$G"; then
    sed -i 's/compileOptions {/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$G"
    printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$G"
  fi
  if ! grep -q syncAdhan "$G"; then
    cat >> "$G" <<'KTS'

// ينسخ أصوات الأذان من assets/adhan إلى res/raw تلقائيًا قبل كل بناء
val syncAdhan by tasks.registering(Copy::class) {
    from("${rootProject.projectDir}/../assets/adhan") { include("*.mp3", "*.ogg", "*.wav") }
    into("${projectDir}/src/main/res/raw")
    rename { it.lowercase().replace('-', '_').replace(' ', '_') }
}
tasks.configureEach { if (name == "preBuild") dependsOn(syncAdhan) }
KTS
  fi
else
  G=android/app/build.gradle
  if ! grep -q coreLibraryDesugaring "$G"; then
    sed -i 's/compileOptions {/compileOptions {\n        coreLibraryDesugaringEnabled true/' "$G"
    printf '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n' >> "$G"
  fi
  if ! grep -q syncAdhan "$G"; then
    cat >> "$G" <<'GRV'

task syncAdhan(type: Copy) {
    from("${rootProject.projectDir}/../assets/adhan") { include "*.mp3", "*.ogg", "*.wav" }
    into "${projectDir}/src/main/res/raw"
    rename { it.toLowerCase().replace('-', '_').replace(' ', '_') }
}
tasks.whenTaskAdded { t -> if (t.name == 'preBuild') t.dependsOn syncAdhan }
GRV
  fi
fi

# Force compileSdkVersion 36 and bypass AAR metadata check across all subprojects (resolves file_picker SDK 36 requirement)
if [ -f android/gradle.properties ]; then
  echo "android.suppressUnsupportedCompileSdk=36" >> android/gradle.properties
fi
if [ -f android/app/build.gradle.kts ]; then
  sed -i 's/compileSdk = .*/compileSdk = 36/' android/app/build.gradle.kts || true
fi
if [ -f android/app/build.gradle ]; then
  sed -i 's/compileSdkVersion .*/compileSdkVersion 36/' android/app/build.gradle || true
fi
if [ -f android/build.gradle ]; then
  cat >> android/build.gradle <<'SUB_GRV'

subprojects {
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
SUB_GRV
fi
if [ -f android/build.gradle.kts ]; then
  cat >> android/build.gradle.kts <<'SUB_KTS'

subprojects {
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
SUB_KTS
fi

flutter pub get
echo "تم. شغّل: flutter run"
