#ifndef SHADOWRUN_EDITION_H
#define SHADOWRUN_EDITION_H

/*
 * Shadowrun's three ROM editions in one executable.
 *
 * The USA release and the German and Swedish translations are different
 * programs: their text changed the code, so each needs its own recompiled
 * tree, and the translations keep the hand cursor 0x1C lower in WRAM. The
 * build links one stock (unprefixed) tree and any number of prefixed program
 * modules; this file is what picks the module that matches the ROM the
 * player supplied, before the guest runs.
 *
 * The data table is generated at configure time from rom_identity*.txt, so
 * the digests still live in exactly one place:
 *
 *   tools/gen_editions.py  ->  shadowrun_editions_data.c
 *
 * A build with several editions linked is a UNIVERSAL build: the same
 * executable accepts any of the ROMs it was built for, and refuses the rest
 * with the editions it does support. A single-edition build is the same
 * binary with one row in the table.
 */

#include <stddef.h>
#include <stdint.h>

#include "rom_identity.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ShadowrunEditionDef {
    const char *tag;            /* "us", "de", "sv" */
    const char *module_id;      /* program-module id in the registry */
    const char *display_name;   /* from rom_identity*.txt */
    const char *rom_file;       /* from rom_identity*.txt */
    const char *expected_sha256;
    const char *expected_sha1;
    const char *expected_crc32;
    unsigned cursor_x;          /* $7E01F0 (USA) or $7E01D4 (translations) */
    unsigned cursor_y;
    unsigned cursor_gate;       /* nonzero while the hand is up */
    const char *save_root;      /* per-edition SRAM + save-state directory */
} ShadowrunEditionDef;

extern const ShadowrunEditionDef kShadowrunEditionDefs[];
extern const unsigned kShadowrunEditionDefCount;
extern const unsigned kShadowrunStockEditionIndex;

/* The same data in the framework's "known dump" shape, for refusal text and
 * the launcher's catalog. */
extern const SnesRomRevision kShadowrunRomRevisions[];
extern const int kShadowrunRomRevisionCount;
extern const char *const kShadowrunKnownSha1Hex[];
extern const int kShadowrunKnownSha1Count;

/* Host hook: the ROM bytes, before SnesInit. Matches the image against each
 * linked module, selects the one that owns it, and sets the edition's save
 * root. A ROM that belongs to none of the linked editions is fatal -- booting
 * it on another edition's dispatch table would execute one game's code with
 * another game's data. */
void ShadowrunOnRomLoaded(const uint8_t *rom, size_t size);

/* The edition selected by ShadowrunOnRomLoaded(), or the stock edition when
 * nothing has been selected yet. */
const ShadowrunEditionDef *ShadowrunActiveEdition(void);

unsigned ShadowrunCursorX(void);
unsigned ShadowrunCursorY(void);
unsigned ShadowrunCursorGate(void);

#ifdef __cplusplus
}
#endif

#endif /* SHADOWRUN_EDITION_H */
