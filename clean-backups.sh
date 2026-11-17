#!/usr/bin/env bash
# LOCKIN：刪除多餘的 html_backup_* 備份，只保留 20261116_073915（2026-11-16 改版前的真實備份）。
# 刪除清單寫死，不用萬用字元，避免誤刪。
set -uo pipefail

KEEP=/home/ubuntu/html_backup_20261116_073915
DEL="
/home/ubuntu/html_backup_20260704_165648
/home/ubuntu/html_backup_20260706_095504
/home/ubuntu/html_backup_20260716_024001
/home/ubuntu/html_backup_20260716_064635
/home/ubuntu/html_backup_20260816_065200
/home/ubuntu/html_backup_20261116_073916
/home/ubuntu/html_backup_20261116_073917
"

echo "=========== 刪除前 ==========="
du -sh /home/ubuntu/html_backup_* 2>/dev/null
df -h / | tail -1
echo

echo "=========== 開始刪除 ==========="
for d in $DEL; do
  if [ -d "$d" ]; then
    rm -rf -- "$d" && echo "已刪除 $d"
  else
    echo "略過（不存在）$d"
  fi
done
echo

echo "=========== 保留檢查 ==========="
if [ -d "$KEEP" ]; then
  echo "保留中：$(du -sh "$KEEP")"
else
  echo "!!! 警告：原本要保留的 $KEEP 不存在"
fi
echo

echo "=========== 刪除後 ==========="
du -sh /home/ubuntu/html_backup_* 2>/dev/null || echo "(沒有備份資料夾了)"
df -h / | tail -1
echo
echo "=== CLEAN DONE ==="
