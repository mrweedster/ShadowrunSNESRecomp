/*
 * Shadowrun — per-game runtime glue.
 *
 * THIS FILE IS THE PORT. Everything else the scaffold produced is layout,
 * build wiring, and packaging; this is where the actual work happens.
 *
 * The framework does not, and cannot, drive an arbitrary SNES game on its
 * own. Two responsibilities always land on the game host:
 *
 *   1. Deciding what "one frame" means for THIS title, and returning from
 *      run_frame() at that boundary. A real ROM's reset vector never
 *      returns — it enters a main loop that waits on vblank — so somebody
 *      has to choose the yield point.
 *   2. Delivering NMI/IRQ at the hardware edge (see
 *      snesrecomp/docs/FRAME_MODEL_HOSTS.md).
 *
 * A new port starts on the framework's beam-aligned driver
 * (runner/src/beam_frame_driver.h): one frame is one PPU field, cut at the
 * beam's vblank edge; interrupts -- raster splits and a coprocessor's IRQ
 * line -- are taken where the beam latches them; parked time still runs the
 * beam, APU and coprocessors; and the field is rasterized from the raster
 * journal with real HDMA. It is the framework's, so a fix to it reaches this
 * port on a submodule pull.
 *
 * This file used to hold its own copy of a simpler driver: frames measured
 * from wherever the CPU last stopped, NMI delivered at an arbitrary beam
 * position, the field drawn with end-of-frame register state. A game that
 * uploads in vblank between INIDISP=$80 and $0F flickered black, and one
 * that chains raster splits fell apart. Replace these calls only for what
 * the driver does not do; MetalWarriorsSNESRecomp's src/mw_rtl.c and
 * GundamWingEndlessDuelSNESRecomp's src/game_rtl.c are developed examples of
 * title-specific drivers.
 */

#include "game_rtl.h"

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "beam_frame_driver.h"
#include "host_report.h"
#include "snes/interp_bridge.h"

#include "mouse_cursor.h"

/*
 * Declared idle polls (snesrecomp/docs/IDLE_POLL.md).
 *
 * Shadowrun waits for its own next frame by comparing a WRAM word against a
 * register and branching back to the compare:
 *
 *   $81:B05D  AF 92 1C 7E   LDA $7E1C92      entry: read the counter
 *   $81:B061  CF 92 1C 7E   CMP $7E1C92  \   the wait, and the PC the compiled
 *   $81:B065  F0 FA         BEQ $B061    /   body yields back to every frame
 *   $81:B067  6B            RTL
 *
 *   $81:EE8E  CF 92 1C 7E   CMP $7E1C92      the same wait in another routine,
 *   $81:EE92  F0 FA         BEQ $EE8E        demanded in M1X0 and M1X1
 *
 * $7E1C92 is the game's frame counter: in the r9 framedump corpus it advances
 * by exactly one every host frame over f16000..f16199 (evidence/m2_promotion_
 * round3.md §1), which is the promise IDLE_POLL.md asks the host to make -- the
 * byte changes only when an interrupt handler runs. Declaring the poll lets the
 * bridge replay that cycle to the frame deadline instead of interpreting it:
 * same guest clock, cycle count, refresh, open bus, APU time, resume PC and
 * registers. A cycle that writes, reads a device, or could meet an IRQ is
 * interpreted as if nothing had been declared, so a wrong declaration is a
 * lost speedup and not a behaviour change.
 *
 * Two PCs, and only these two. The next wait on the list, $81:F007
 * (`CMP $2140 / BNE $F007`, 5.0 M cycles), is not declared: its read is
 * DB-register-relative, so the bus address is not provable from the ROM, and
 * $7E2140 reads 0 at every sampled frame edge -- the promise cannot be
 * established, so the speedup is left on the table.
 *
 * The framework exposes the table but no host fills it in, so this is
 * title-owned. Nothing is declared unless asked: SNESRECOMP_IDLE_POLLS is a
 * comma-separated list of hex PCs, `off` to declare none. Round 3 measured the
 * pair that way, with both legs on one executable.
 */
#define kIdlePollLimit 8 /* interp_bridge_set_idle_poll's own table size */

/* strcasecmp is POSIX and <strings.h> does not exist under MSVC. The port
 * builds on Windows as well as macOS/Linux, and the only use here compares
 * against "off", so a local ASCII-only comparison is the whole requirement. */
static int AsciiEqualIgnoreCase(const char *a, const char *b)
{
    while (*a && *b) {
        unsigned char ca = (unsigned char)*a++;
        unsigned char cb = (unsigned char)*b++;
        if (ca >= 'A' && ca <= 'Z') ca = (unsigned char)(ca - 'A' + 'a');
        if (cb >= 'A' && cb <= 'Z') cb = (unsigned char)(cb - 'A' + 'a');
        if (ca != cb) return 0;
    }
    return *a == *b;
}

static void DeclareIdlePolls(void)
{
    const char *spec = getenv("SNESRECOMP_IDLE_POLLS");
    if (!spec || !*spec || AsciiEqualIgnoreCase(spec, "off"))
        return;

    char buf[256];
    snprintf(buf, sizeof buf, "%s", spec);
    int declared = 0, refused = 0;
    for (char *tok = strtok(buf, ",; "); tok; tok = strtok(NULL, ",; ")) {
        char *end = NULL;
        unsigned long pc = strtoul(tok, &end, 16);
        if (!end || *end || pc > 0xFFFFFFul) {
            host_report_breadcrumb("idle-poll: '%s' is not a 24-bit hex PC; skipped", tok);
            continue;
        }
        if (interp_bridge_set_idle_poll((uint32_t)pc)) {
            host_report_breadcrumb("idle-poll: declared $%06X (docs/IDLE_POLL.md)", pc);
            declared++;
        } else {
            refused++;
        }
    }
    if (refused)
        host_report_breadcrumb("idle-poll: %d PC(s) refused, table full at %d slots",
                               refused, kIdlePollLimit);
    fprintf(stderr, "[shadowrun] idle polls declared: %d\n", declared);
}

void GameRunOneFrame(void)
{
    /* The host has already put this frame's controller word in
     * g_snes->input1_currentState (RtlRunFrame, before run_frame). Mouse
     * buttons may add to it and the hand cursor may be placed outright. */
    MouseCursorBeginFrame();
    snes_beam_frame_driver_run_frame();
}

void GameDrawPpuFrame(void)
{
    snes_beam_frame_driver_draw_ppu_frame();
}

void GameSessionReset(void)
{
    /* Rematch / soft-return: clear anything that must not survive a new
     * session. recomp-ai-rules/NETPLAY.md §3 — sticky state that "has always
     * been fine" is the usual desync culprit, because single-player never
     * re-enters the boot path twice in one process. */
    snes_beam_frame_driver_reset();
}

const RtlGameInfo kGameInfo = {
    .title = "shadowrun",
    .initialize = &DeclareIdlePolls,
    .run_frame = &GameRunOneFrame,
    .draw_ppu_frame = &GameDrawPpuFrame,
    .save_name_prefix = "save",
    .session_reset = &GameSessionReset,
};
