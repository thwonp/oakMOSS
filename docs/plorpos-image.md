# plorpOS images (Zero 28, Zero 40)

How this fork builds the Zero 28 and Zero 40 images with plorpOS already in
them. The base is oakMOSS as it is; the image adds the plorpOS card files, and
nothing else about the board changes. The logo stays oakMOSS's.

## What the image adds

- `/usr/magicx/plorpos-payload/`: the contents of the board's plorpOS card zip
  (`plorpOS-v<version>-<board>.zip`): `.tmp_update/updater`, `plorpOS/`, `Roms/`,
  `Saves/`, `Bios/`, `Music/`, `Audiobooks/`.
- `oakmoss-plorpos.sh` (`overlay/usr/magicx/bin/`), called by `runmagicx.sh` after
  the cards are mounted and before the hand-off. It copies the payload onto SD1's
  `SPRUCEOS` partition when, and only when:
  - no card has a frontend (`.tmp_update/updater` or `magicx/init.sh`),
  - SD2 is not the host, and
  - SD1 has no `plorpOS/` folder.

  It tries once per boot and cleans up a copy that failed, so a full or broken
  card cannot loop the start-up. Then the election runs again and finds the
  updater. A card that already has plorpOS, spruceOS or another launcher is never
  touched. plorpOS updates itself from then on (its own updater), and an image
  update (`.omupd`) replaces the system only.

The first boot makes the `SPRUCEOS` partition (docs/cards.md), so the image
cannot carry the files in a partition; they travel in the root filesystem.

## Building

As docs/building.md, plus the payload:

```
PLORPOS_PAYLOAD=/path/to/plorpOS-v<version>-zero28.zip scripts/build.sh all zero28
```

`PLORPOS_PAYLOAD` is read by the `image` step only. `build.sh` refuses a zip
that is not a plorpOS card zip, or is for another board (the board name in
`.tmp_update/updater` must match `DEVICE_MARKER`). The payload adds its size to
the root filesystem (about 300 MB unpacked for the Zero 28), which has to fit
the 512 MiB slot. Without `PLORPOS_PAYLOAD` the build is plain oakMOSS.

Outputs, in `builds/<stamp>-<board>/`: the raw card image (`*-sd1.img`, the whole
card) and, on the Zero 28, the update package (`*.omupd`, docs/updates.md).

### Zero 40: the hybrid

The Zero 40 boots Shaun Inman's boot chain and kernel (main-zero40), not ours:
the SDK has neither its panel nor its touch driver. So the Zero 40 image is the
hybrid (`scripts/make-hybrid-zero40.sh`): his chain with our root filesystem.

```
PLORPOS_PAYLOAD=.../plorpOS-v<version>-zero40.zip scripts/build.sh all zero40
scripts/make-hybrid-zero40.sh builds/<stamp>-zero40
```

- The Zero 40 build wants MagicX's encrypt object (`inputs/README.md`). In the
  hybrid the kernel that build makes is not used, so a build without the object
  can set `ENCRYPT_OBJ=sdk` in `boards/zero40/board.conf` for that build. The
  hybrid built this way (2026-11-27) has been built, not yet flashed. Never flash the plain
  `*-sd1.img` of such a build on a Zero 40; only the hybrid image.
- `adapt-zero40-rootfs.sh` swaps in MagicX's kernel modules. It keeps our USB
  audio modules and their autoload entry (checked against the kernel's vermagic),
  so a DAC works with or without plorpOS loading anything.
- The hybrid has no second slot, so there is no `.omupd` for it: the Zero 40 is
  a raw image only.

## Known problems with a stock SDK

Found by building from the SDK as it ships (tracked as plorpos-bvr, not all
fixed here):

1. `apply-sdk-mods.sh` refused a pristine SDK: the debug-patch check cannot apply
   before oakMOSS's own patches create the files it edits. Fixed: with no
   `.oakmoss-mods` stamp the mismatch is not a stray edit.
2. Patch 060 was reported as already in the tree: the line it adds also exists
   in util-linux's host block. Fixed: a patch that still applies forward is not
   in the tree; the in-tree test is for one that no longer applies.
3. OpenixCard: the pinned `inicpp` submodule commit is gone upstream, and it
   needs automake and libconfuse. Not fixed. Build it in a container
   (ubuntu 22.04 with `cmake g++ make pkg-config autoconf automake libtool m4
   libconfuse-dev git`), and point `OPENIXCARD_LIBDIR` at the libconfuse it
   links.
4. The host needs GNU `patch` (not BusyBox) on `PATH`.

## Testing without a card

`oakmoss-plorpos.sh` takes `PAYLOAD`, `STATE` (the `/tmp/oakmoss-cards` file) and
`LOG` from the environment. Point `STATE` at a file with `HOST`, `SD1_ROOT` and
`SD2_ROOT` set to folders, delete `/tmp/oakmoss-plorpos-tried` between runs, and
run `oakmoss-plorpos.sh seed`. Tested this way (2026-11-27): empty card seeds,
second boot does nothing, a card with a launcher is left alone, SD2 as host is
left alone, a `plorpOS/` folder without a hand-off is refused, a read-only card
is cleaned up. FAT behaviour and the real first boot are not covered.
