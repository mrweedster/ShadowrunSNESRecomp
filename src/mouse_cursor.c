/*
 * Shadowrun mouse mod — absolute hand cursor and mouse action buttons.
 *
 * WHERE THE CURSOR LIVES
 *
 * Shadowrun draws the hand cursor as OAM sprite 0 and keeps its position in
 * two 8.8 fixed-point WRAM words (high byte = screen pixel, low byte =
 * sub-pixel; the game only ever uses whole pixels):
 *
 *     $7E01F0   cursor X   (x << 8)
 *     $7E01F2   cursor Y   (y << 8)
 *     $7E01F4   nonzero while the hand is up
 *
 * The German and Swedish translations keep the same three words at
 * $7E01D4/$7E01D6/$7E01D8: their inserted text moved the code, and this WRAM
 * block with it, 0x1C lower. A universal executable carries all three
 * editions, so the addresses are chosen at runtime from the edition whose ROM
 * was loaded (src/edition.c); see evidence/language_roms.md for the
 * measurement.
 *
 * $7E01F4 is the gate. With the hand down the same two words hold the
 * screen origin the room is drawn from, so writing them then scrolls the
 * level instead of moving the pointer. They were identified by diffing
 * WRAM dumps of the same boot route with one direction held for 30 frames:
 * only $7E01F0 (right/left) and $7E01F2 (up/down) moved, and a one-frame
 * C:1F0 poke moved the drawn hand and stuck, with the game's own d-pad
 * movement continuing from the poked position.
 *
 * Measured cursor box (hand held right/left/up/down to its limits):
 * x 3..239, y 3..206 on a 256x224 field — the game clamps to that on its
 * own, the numbers here only keep a write inside the screen so the hand
 * never flickers against a clamp.
 *
 * WHY THE MOUSE IS ARMED BY INPUT
 *
 * snesrecomp_desktop_mouse_state() answers only while the game window has
 * the pointer, but the SDL dummy driver used by the headless test harness
 * also has a window and can report a pointer. A scripted regression leg must
 * not have its R-and-aim routes rewritten by that phantom, so the mod stays
 * inert until it has seen the pointer actually move or a button actually go
 * down. A real player arms it with the first motion or click; a test leg
 * never does.
 *
 * THE OS POINTER
 *
 * While the pointer is over the game image the host hides the OS arrow
 * (snesrecomp_desktop_set_game_pointer), because the guest hand is drawn
 * under it; only one pointer should be on screen. Moving out of the image,
 * switching applications, or the fullscreen cursor key brings the OS arrow
 * back and the next frame over the image hides it again.
 */

#include "mouse_cursor.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "common_rtl.h"
#include "common_cpu_infra.h"
#include "snes/snes.h"
#include "desktop/sdl_compat.h"
#include "host_main.h"
#include "edition.h"

/* WRAM cursor words, and the gate that says the hand is up. The addresses are
 * per ROM edition: the USA release keeps them at $7E01F0/2/4, the German and
 * Swedish translations at $7E01D4/6/8 because their text moved the code and
 * this block with it. ShadowrunCursorX/Y/Gate() read the edition the loaded
 * ROM selected (src/edition.c), so one binary serves all three. */
#define kCursorX        ShadowrunCursorX()
#define kCursorY        ShadowrunCursorY()
#define kCursorVisible  ShadowrunCursorGate()

/* SNES pad bits (active high), as read from $4218. */
#define kPadB  0x0001u
#define kPadY  0x0002u
#define kPadA  0x0100u

/* The hand sprite is 16x16; the guest's own clamp stops at the last
 * position where it still fits inside the field (measured, not guessed). */
#define kCursorMaxX(field_w) ((field_w) - 17)
#define kCursorMaxY(field_h) ((field_h) - 18)

void MouseCursorBeginFrame(void)
{
    int mx = 0, my = 0;
    unsigned buttons = 0;

    const int inside = snesrecomp_desktop_mouse_state(&mx, &my, &buttons) != 0;

    /* While the pointer is over the image the OS arrow is hidden: the guest
     * hand is already under it. Outside the image (or with another app in
     * front) the pointer comes back. The host layers this over its own
     * cursor setting, and drops the hide on focus loss. */
    snesrecomp_desktop_set_game_pointer(inside);

    /* Harness hook: a GUI leg run without Accessibility permission cannot
     * post a real click, so SNESRECOMP_MOUSE_TEST_BUTTONS=<mask>[:<from>]
     * [:<to>] injects the same SDL button mask a real click would report,
     * between guest frames <from> and <to>. Off unless set. */
    if (inside) {
        const char *tb = getenv("SNESRECOMP_MOUSE_TEST_BUTTONS");
        if (tb && *tb && *tb != '0') {
            char *end = NULL;
            const unsigned mask = (unsigned)strtoul(tb, &end, 0);
            long from = 0, to = 0x7fffffffL;
            if (end && *end == ':') from = strtol(end + 1, &end, 0);
            if (end && *end == ':') to = strtol(end + 1, NULL, 0);
            if (snes_frame_counter >= from && snes_frame_counter < to)
                buttons |= mask;
        }
    }

    /* Arm on real motion or a real button press: see the header comment. */
    static int have_last;
    static int last_x, last_y;
    static int armed;
    if (inside) {
        if (buttons != 0) armed = 1;
        if (have_last && (mx != last_x || my != last_y)) armed = 1;
        have_last = 1;
        last_x = mx;
        last_y = my;
    }

    if (!inside)
        return;

    /* A = right button, B = left button, Y = middle button. Added to the
     * word the host assembled for this frame (keyboard, gamepad, script), so
     * a rebound keyboard button or a pad still works alongside the mouse. */
    uint16 pad_now = 0;
    if (armed && g_snes) {
        uint16 pad = g_snes->input1_currentState;
        if (buttons & SDL_BUTTON_RMASK) pad |= kPadA;
        if (buttons & SDL_BUTTON_LMASK) pad |= kPadB;
        if (buttons & SDL_BUTTON_MMASK) pad |= kPadY;
        if (pad != g_snes->input1_currentState)
            RtlSetPadState(0, pad);
        pad_now = g_snes->input1_currentState;
    }

    if (!armed)
        return;

    /* Absolute pointer, hand up only: the edition's gate word nonzero. */
    const unsigned cursor_gate = kCursorVisible;
    const int hand_up =
        (g_ram[cursor_gate] | g_ram[cursor_gate + 1]) != 0;

    int cursor_x = mx, cursor_y = my;
    if (hand_up) {
        const int field_w = snesrecomp_desktop_frame_width();
        const int field_h = snesrecomp_desktop_frame_height();
        const int max_x = kCursorMaxX(field_w);
        const int max_y = kCursorMaxY(field_h);
        if (cursor_x < 3) cursor_x = 3;
        if (cursor_y < 3) cursor_y = 3;
        if (cursor_x > max_x) cursor_x = max_x;
        if (cursor_y > max_y) cursor_y = max_y;

        g_ram[kCursorX] = 0x00;                       /* sub-pixel */
        g_ram[kCursorX + 1] = (uint8_t)cursor_x;      /* x << 8 */
        g_ram[kCursorY] = 0x00;
        g_ram[kCursorY + 1] = (uint8_t)cursor_y;
    }

    /* SNESRECOMP_MOUSE_DEBUG=1: what the mod did, when it changes. */
    static int debug = -1;
    static int shown_x = -1, shown_y = -1, shown_hand = -1;
    static unsigned shown_buttons = ~0u;
    if (debug < 0) {
        const char *v = getenv("SNESRECOMP_MOUSE_DEBUG");
        debug = (v && *v && *v != '0') ? 1 : 0;
    }
    if (debug && (cursor_x != shown_x || cursor_y != shown_y ||
                  buttons != shown_buttons || hand_up != shown_hand)) {
        shown_x = cursor_x;
        shown_y = cursor_y;
        shown_buttons = buttons;
        shown_hand = hand_up;
        fprintf(stderr, "[mouse] pointer %d,%d buttons 0x%02x hand %s pad 0x%04x\n",
                cursor_x, cursor_y, buttons, hand_up ? "up" : "down",
                (unsigned)pad_now);
    }
}
