/*
 * Runtime edition selection for the universal Shadowrun executable.
 *
 * Each linked generated tree registers itself with the framework's program
 * module registry (runner/src/program_module.h) and carries the SHA-256 and
 * size of the ROM image it was generated from. The host hands us the bytes of
 * the ROM the player chose before SnesInit; we look for the module that owns
 * those bytes and make it the CPU's dispatch table. Nothing here executes
 * guest code.
 *
 * This is the whole reason the universal build is safe: a module is only
 * selected when its generated code and the image agree byte for byte. A USA
 * tree running a German ROM is exactly the "architecture went off the rails"
 * failure the language-edition work measured, so an unknown image stops the
 * process instead of booting it on the stock module.
 */

#include "edition.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(SNESRECOMP_SETUP_HOST) || !SNESRECOMP_SETUP_HOST
#include "common_rtl.h"
#include "host_report.h"
#include "program_module.h"
#include "sha256.h"
#endif

/* The selected edition, or NULL before a ROM has been matched. */
static const ShadowrunEditionDef *s_active;

const ShadowrunEditionDef *ShadowrunActiveEdition(void)
{
    if (s_active)
        return s_active;
    if (kShadowrunEditionDefCount == 0)
        return NULL;
    return &kShadowrunEditionDefs[kShadowrunStockEditionIndex];
}

unsigned ShadowrunCursorX(void) { return ShadowrunActiveEdition()->cursor_x; }
unsigned ShadowrunCursorY(void) { return ShadowrunActiveEdition()->cursor_y; }
unsigned ShadowrunCursorGate(void) { return ShadowrunActiveEdition()->cursor_gate; }

#if defined(SNESRECOMP_SETUP_HOST) && SNESRECOMP_SETUP_HOST
/* A setup host links no generated code at all; SnesInit refuses to boot a
 * guest and the launcher's Generate & rebuild is the only path. There is no
 * module to match, and exiting here would hide that explanation. */
void ShadowrunOnRomLoaded(const uint8_t *rom, size_t size)
{
    (void)rom;
    (void)size;
}
#else
static const ShadowrunEditionDef *EditionForModule(const char *module_id)
{
    for (unsigned i = 0; i < kShadowrunEditionDefCount; ++i) {
        if (strcmp(kShadowrunEditionDefs[i].module_id, module_id) == 0)
            return &kShadowrunEditionDefs[i];
    }
    /* The stock tree is generated with --module-id main whatever the edition,
     * so its descriptor says "main" even in a single-edition German build.
     * The build's table says which edition that tree is. */
    return &kShadowrunEditionDefs[kShadowrunStockEditionIndex];
}

/* A copier header is 512 bytes past a 1 KiB boundary. The generated trees
 * and their recorded digests cover the bare image, so strip it here exactly
 * as the framework's verifier does. */
static void StripCopierHeader(const uint8_t **rom, size_t *size)
{
    if (*rom && *size >= 0x200 && (*size % 0x400) == 0x200) {
        *rom += 0x200;
        *size -= 0x200;
    }
}

/* The failure path is the one report we get from a machine we cannot run on,
 * so record what was actually supplied next to what the build expects. */
static void HexSha256(const uint8_t *rom, size_t size, char hex[65])
{
    static const char kHex[] = "0123456789abcdef";
    uint8_t digest[32];
    sha256_compute(rom, size, digest);
    for (unsigned i = 0; i < 32; ++i) {
        hex[i * 2] = kHex[digest[i] >> 4];
        hex[i * 2 + 1] = kHex[digest[i] & 15];
    }
    hex[64] = '\0';
}

void ShadowrunOnRomLoaded(const uint8_t *rom, size_t size)
{
    StripCopierHeader(&rom, &size);

    const unsigned registered = snes_program_module_count();
    host_report_breadcrumb("edition selection: image %zu bytes, %u module(s) "
                           "registered", size, registered);

    const SnesProgramModule *match = NULL;
    for (unsigned i = 0; i < registered; ++i) {
        const SnesProgramModule *module = snes_program_module_at(i);
        if (module && snes_program_module_rom_matches(module, rom, size)) {
            match = module;
            break;
        }
    }

    if (!match) {
        char sha256[65];
        HexSha256(rom, size, sha256);
        host_report_breadcrumb("edition selection: no module matches image "
                               "%zu bytes, sha256 %s", size, sha256);
        fprintf(stderr,
                "[shadowrun] ROM is not one of the editions this build carries "
                "(%zu bytes, SHA-256 %s).\n", size, sha256);
        if (registered == 0) {
            /* The registry comes up empty when the generated trees' .CRT$XCU
             * entries were dropped; MSVC Release does that to a static entry,
             * which is why program_module.h uses external linkage plus
             * /include:. Name the defect instead of blaming the ROM. */
            fprintf(stderr,
                    "[shadowrun] no program module registered at all: this "
                    "build linked no registration constructor (see "
                    "runner/src/program_module.h).\n");
        }
        for (unsigned i = 0; i < kShadowrunEditionDefCount; ++i) {
            fprintf(stderr, "[shadowrun]   %s: %s [SHA-256 %s]\n",
                    kShadowrunEditionDefs[i].tag,
                    kShadowrunEditionDefs[i].display_name,
                    kShadowrunEditionDefs[i].expected_sha256);
        }
        fprintf(stderr,
                "[shadowrun] Use --rom with one of those dumps, or regenerate "
                "this tree for the edition you own.\n");
        exit(1);
    }

    /* Before the guest runs, and before SnesInit reads the image: the module
     * owns the dispatch/guard tables the CPU will use. */
    snes_program_module_select(match);
    s_active = EditionForModule(match->id);

    /* SRAM and save-state slots are per edition. The games' save data is not
     * interchangeable either, so sharing saves/ would silently mix them. */
    RtlSetSaveRoot(s_active->save_root);
    RtlEnsureSaveDir();

    host_report_breadcrumb("edition selection: %s (%s), module %s, saves %s",
                           s_active->tag, s_active->display_name, match->id,
                           s_active->save_root);
    if (registered != kShadowrunEditionDefCount)
        host_report_breadcrumb("edition selection: WARNING %u module(s) "
                               "registered for %u edition table row(s)",
                               registered, kShadowrunEditionDefCount);
    fprintf(stderr, "[shadowrun] edition: %s (%s), module %s, saves %s\n",
            s_active->tag, s_active->display_name, match->id,
            s_active->save_root);
}
#endif
