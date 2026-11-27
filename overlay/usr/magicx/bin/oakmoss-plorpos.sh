#!/bin/sh
# plorpOS in the image (images built with PLORPOS_PAYLOAD, scripts/build.sh): the rootfs carries the
# plorpOS zip's contents in /usr/magicx/plorpos-payload. On a card that has no frontend, they are
# copied onto SD1's SPRUCEOS partition (the plorpOS/ folder, Roms/, Saves/, .tmp_update/updater ...,
# as the zip unpacks on any card), and the normal election then finds .tmp_update/updater and starts
# plorpOS. Once. A card that has plorpOS, spruceOS or any other frontend is never touched, and
# neither is a card plorpOS has since updated itself on: its own updater owns the folder from then on.
#
#   oakmoss-plorpos.sh seed     after oakmoss-cards.sh mount; exit 0 = copied (elect again), 1 = nothing done
#
# PAYLOAD, STATE and LOG exist for testing.
PAYLOAD=${PAYLOAD:-/usr/magicx/plorpos-payload}
STATE=${STATE:-/tmp/oakmoss-cards}
LOG=${LOG:-/mnt/UDISK/oakmoss-boot.log}
log() { echo "$(cut -d' ' -f1 /proc/uptime) plorpos: $*" >> "$LOG" 2>/dev/null; }

[ "$1" = seed ] || { echo "usage: oakmoss-plorpos.sh seed" >&2; exit 2; }
[ -d "$PAYLOAD" ] || exit 1
[ -e /tmp/oakmoss-plorpos-tried ] && exit 1      # one try per boot: a failure must not loop
: > /tmp/oakmoss-plorpos-tried
HOST=none SD1_ROOT= SD2_ROOT=
[ -f "$STATE" ] && . "$STATE"
frontend() { [ -f "$1/magicx/init.sh" ] || [ -f "$1/.tmp_update/updater" ]; }
[ -n "$SD1_ROOT" ] || exit 1
[ "$HOST" = sd2 ] && exit 1
frontend "$SD1_ROOT" && exit 1
[ -n "$SD2_ROOT" ] && frontend "$SD2_ROOT" && exit 1
[ -e "$SD1_ROOT/plorpOS" ] && { log "SD1 has a plorpOS folder but no hand-off; left alone"; exit 1; }

need=$(du -sk "$PAYLOAD" | cut -f1)
free=$(df -k "$SD1_ROOT" | awk 'NR==2 {print $4}')
[ -n "$free" ] && [ "$free" -gt $((need + need / 10 + 1024)) ] || { log "SD1: ${free:-?} KiB free, the payload needs $need KiB"; exit 1; }

log "seeding $SD1_ROOT with the plorpOS payload ($need KiB)"
if cp -R "$PAYLOAD"/. "$SD1_ROOT"/ 2>> "$LOG" && sync && [ -f "$SD1_ROOT/.tmp_update/updater" ]; then
    log "plorpOS seeded"
    exit 0
fi
log "seeding failed; removing the partial copy"
rm -rf "$SD1_ROOT/plorpOS" "$SD1_ROOT/.tmp_update"
sync
exit 1
