/*
 * Shadowrun — desktop host shim.
 *
 * Identity and hooks, nothing else. The host itself is the framework's
 * (snesrecomp/runner/src/desktop/host_main.h): the pre-boot launcher, ROM
 * resolution and digest checks, config.ini and keybinds.ini, the window and
 * the SDL / OpenGL presenters, audio, gamepads, the in-game save-state
 * browser and rewind filmstrip, the OSD, the pacing clock, crash handlers and
 * the post-mortem report, mod packages, Generate & rebuild, and the netplay
 * barrier when the project is built with it. A fix there reaches this
 * project on a submodule pull; nothing in this file needs to change for it.
 *
 * This file used to BE the host -- a ~700-line copy made at scaffold time --
 * so every project scaffolded before a fix kept the bug. Two ports of the
 * same game, a week apart, had different hosts.
 *
 * Nothing here ever ships a ROM. The player supplies one; the host makes
 * that easy (launcher, then positional argument, then a copy beside the
 * executable, then the rom.cfg cache, then a file picker) and checks what it
 * is handed against the digests in rom_identity.txt.
 *
 * Grow this file only with what is specific to THIS title: a custom
 * presenter (prepare_frame / draw_frame), an SPC player, a pacing rule
 * (keep_pacing_debt), a Mods provider. See SnesDesktopHostGame for the
 * complete list of hooks and what each is for.
 */

#include "host_main.h"
#include "game_rtl.h"
#include "edition.h"
#include "snesrecomp_rom_identity.h"  /* generated from rom_identity*.txt */

#ifndef __ANDROID__
#define SDL_MAIN_HANDLED 1
#endif
#include "desktop/sdl_compat.h"
#ifdef __ANDROID__
/* SDLActivity loads libmain.so and dlsyms its SDL_main. */
#define main SDL_main
#endif

#ifndef SNES_GAME_VERSION
#define SNES_GAME_VERSION "dev"
#endif

#if SHADOWRUN_UNIVERSAL
/* The framework host can verify one digest. A universal executable carries
 * several, so it verifies none here: ShadowrunOnRomLoaded matches the image
 * against every linked module's recorded digest before the guest can run. */
#define SHADOWRUN_EXPECTED_SHA256 ""
#define SHADOWRUN_EXPECTED_CRC32  ""
#define SHADOWRUN_REGION          NULL
#define SHADOWRUN_ROM_HELP \
    "This build carries more than one Shadowrun edition. Supply one of its " \
    "dumps with --rom; the executable selects that edition itself."
#else
#define SHADOWRUN_EXPECTED_SHA256 SNESRECOMP_ROM_EXPECTED_SHA256
#define SHADOWRUN_EXPECTED_CRC32  SNESRECOMP_ROM_EXPECTED_CRC32
#define SHADOWRUN_REGION          SNESRECOMP_ROM_REGION
#define SHADOWRUN_ROM_HELP        NULL
#endif

static SnesDesktopHostGame kGameHost = {
    .display_name        = "Shadowrun",
    .window_title        = "Shadowrun",
    .region              = SHADOWRUN_REGION,
    .rom_file            = SNESRECOMP_ROM_FILE,
    .expected_sha256_hex = SHADOWRUN_EXPECTED_SHA256,
    .expected_crc32_hex  = SHADOWRUN_EXPECTED_CRC32,
    .game_id             = SNESRECOMP_ROM_GAME_ID,
    .build_version       = SNES_GAME_VERSION,
    .game_info           = &kGameInfo,
    .num_players         = 2,
    /* Battery-backed SRAM shows the launcher's SAVES panel. Leave NULL for a
     * title without one. The path is exe-relative; ShadowrunOnRomLoaded
     * switches the root to saves/<edition>/ once the ROM is known. */
    .sram_path           = "saves/save.srm",
    /* Before SnesInit: pick the program module whose generated tree owns the
     * image, and set that edition's cursor words and save root. */
    .on_rom_loaded       = &ShadowrunOnRomLoaded,
    .known_sha1_hex      = kShadowrunKnownSha1Hex,
    .rom_revisions       = kShadowrunRomRevisions,
    .rom_help            = SHADOWRUN_ROM_HELP,
};

#ifndef __ANDROID__
#undef main   /* desktop: keep plain main() even if SDL_main.h remapped it */
#endif
int main(int argc, char **argv)
{
    /* The edition table is generated, so its sizes are objects rather than
     * integer constant expressions; fill them in here. */
    kGameHost.num_known_sha1 = kShadowrunKnownSha1Count;
    kGameHost.num_rom_revisions = kShadowrunRomRevisionCount;
    return snesrecomp_desktop_main(&kGameHost, argc, argv);
}
