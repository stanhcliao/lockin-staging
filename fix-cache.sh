#!/usr/bin/env bash
# LOCKIN：(1) 列出備份資料夾 (2) 幫 nginx 加上快取標頭
# 安全原則：找不到「剛好一個」目標設定檔就完全不動；改完一定跑 nginx -t，失敗立刻還原。
set -uo pipefail

echo "=========== 1) 備份資料夾 ==========="
if ls -d /home/ubuntu/html_backup_* >/dev/null 2>&1; then
  du -sh /home/ubuntu/html_backup_* 2>/dev/null
else
  echo "(找不到 /home/ubuntu/html_backup_*)"
fi
echo
df -h / | tail -1
echo

echo "=========== 2) 找 nginx 設定檔 ==========="
NGINX_BIN="$(command -v nginx || echo /usr/sbin/nginx)"
"$NGINX_BIN" -v 2>&1 | head -1

HITS="$(grep -rlE '^[[:space:]]*root[[:space:]]+/var/www/html[[:space:]]*;' /etc/nginx /opt/bitnami/nginx/conf 2>/dev/null | sort -u)"
N="$(printf '%s\n' "$HITS" | grep -c . || true)"
echo "含 'root /var/www/html;' 的設定檔：$N 個"
printf '%s\n' "$HITS" | sed 's/^/  /'

if [ "$N" -ne 1 ]; then
  echo
  echo ">>> 不是剛好一個，為安全起見「沒有做任何修改」。以下供診斷："
  grep -rnE 'server_name|^[[:space:]]*root[[:space:]]' /etc/nginx /opt/bitnami/nginx/conf 2>/dev/null | head -40
  exit 0
fi

CONF="$HITS"
SNIP="$(dirname "$CONF")/lockin-cache.conf"
echo "目標設定檔：$CONF"
echo "快取片段  ：$SNIP"
echo

cat > "$SNIP" <<'EOF'
# LOCKIN 快取規則（由 fix-cache.sh 產生，可安全重跑）
# 預設：HTML 等不帶雜湊的檔案每次都向伺服器確認，改版後所有人立刻看到新版。
add_header Cache-Control "no-cache" always;

# Vite 建置產物（檔名自帶內容雜湊，內容永不改變）→ 可長期快取
location ~ ^/assets/[^/]+$ {
    add_header Cache-Control "public, max-age=31536000, immutable" always;
}

# 伺服器自行維護的照片（檔名不帶雜湊，可能被換掉）→ 只快取一天
location ^~ /assets/img/ {
    add_header Cache-Control "public, max-age=86400" always;
}
EOF

if grep -q 'lockin-cache.conf' "$CONF"; then
  echo "include 行已存在 → 只更新片段內容，不再改設定檔。"
else
  BK="$CONF.bak_$(date +%Y%m%d_%H%M%S)"
  cp -a "$CONF" "$BK"
  echo "已備份設定檔：$BK"
  awk -v inc="    include $SNIP;" '
    !ins && $0 ~ /^[[:space:]]*root[[:space:]]+\/var\/www\/html[[:space:]]*;/ { print; print inc; ins=1; next }
    { print }
  ' "$BK" > /tmp/lockin_conf_new && cp /tmp/lockin_conf_new "$CONF"
  echo "已插入 include。"
fi
echo

echo "=========== 測試設定 ==========="
if "$NGINX_BIN" -t 2>&1; then
  systemctl reload nginx 2>/dev/null || "$NGINX_BIN" -s reload
  echo "=== NGINX RELOADED ==="
else
  echo "!!! nginx -t 失敗"
  if [ -n "${BK:-}" ] && [ -f "${BK:-}" ]; then cp -a "$BK" "$CONF"; echo "已還原設定檔"; fi
  rm -f "$SNIP"
  echo "!!! 沒有套用任何改動，網站維持原狀。"
  exit 1
fi
echo

echo "=========== 3) 驗證 ==========="
for u in / /assets/index-C5kcTXzu.js /assets/img/0/favicon.png; do
  printf '%-34s %s\n' "$u" "$(curl -sI "http://127.0.0.1$u" -H 'Host: www.lockincenter.com' | tr -d '\r' | grep -i '^cache-control' || echo '(無 Cache-Control)')"
done
echo
echo "=== ALL DONE ==="
