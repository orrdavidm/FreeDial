#!/bin/zsh
# Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
#
# Remove FreeDial.app.
#   ./uninstall.sh               remove ~/Applications/FreeDial.app
#   ./uninstall.sh --dest DIR    remove DIR/FreeDial.app
#   ./uninstall.sh --purge       also delete saved addresses, the log, and the Keychain passwords
set -eu
dest=$HOME/Applications
purge=0

while (( $# )); do
  case $1 in
    --dest) dest=${2:?--dest needs a directory}; shift 2 ;;
    --purge) purge=1; shift ;;
    -h|--help) sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

rm -rf "$dest/FreeDial.app"
echo "Removed $dest/FreeDial.app"

if (( purge )); then
  user=$USER
  [[ -f $HOME/.config/freedial/config ]] && user=$(sed -n 's/^user=//p' "$HOME/.config/freedial/config" | head -1)
  if [[ -f $HOME/.config/freedial/hosts.tsv ]]; then
    for machine in ${(u)${(f)"$(cut -f1 "$HOME/.config/freedial/hosts.tsv")"}}; do
      security delete-generic-password -s "rdp-$machine" -a "${user:-$USER}" >/dev/null 2>&1 \
        && echo "Deleted Keychain password for $machine"
    done
  fi
  rm -rf "$HOME/.config/freedial" "$HOME/Library/Logs/freedial.log"
  echo "Removed saved addresses and the log"
fi
