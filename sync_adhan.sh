#!/usr/bin/env bash
# ينسخ أصوات الأذان من assets/adhan إلى موارد أندرويد (res/raw) لتعمل مع الإشعارات
set -e
mkdir -p assets/adhan android/app/src/main/res/raw
shopt -s nullglob nocaseglob
for f in assets/adhan/*.mp3 assets/adhan/*.ogg assets/adhan/*.wav; do
  b=$(basename "$f"); n=$(echo "$b" | tr 'A-Z -' 'a-z__')
  if [ "$b" != "$n" ]; then mv "$f" "assets/adhan/$n"; fi
  cp "assets/adhan/$n" "android/app/src/main/res/raw/$n"
done
echo "تمت مزامنة أصوات الأذان"
