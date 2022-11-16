#!/usr/bin/env bash
set -Eeuo pipefail

set_timezone(){
  printf '%b' 'Setting timezone to:\t\n'
  if [ -f "/usr/share/zoneinfo/${TZ-none}" ]; then
    printf '%b' "\t$TZ\t\n"
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
    echo "[Date]\ndate.timezone = \"$TZ\"" > /usr/local/etc/php/conf.d/99_tz.ini
  else
    printf '%b' '\tUTC\t\n'
    echo "[Date]\ndate.timezone = \"UTC\"" > /usr/local/etc/php/conf.d/99_tz.ini
  fi
}
