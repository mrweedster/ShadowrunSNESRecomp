/*
 * cyc_model_diff -- does the interpreted path and the AOT-compiled path charge
 * the SAME cycles for the SAME instruction?
 *
 * The runner has two independent cost models:
 *   floor  : runner/src/snes/interp816.c  (cyclesPerOpcode[] + inline
 *            modifiers, applied per opcode at run time)
 *   folded : runner/src/snes/snes_cycles.h (generated from recompiler/
 *            snes_cycles.py) -- what the AOT emitter bakes into each block as
 *            `cpu->cycles += K;` plus a few runtime `+= 1` conditionals.
 * Shadowrun's hot code is compiled as *_M0X0 (m=0, x=0: 16-bit memory AND
 * 16-bit index registers). This harness runs one opcode through interp816 and
 * compares against the folded charge with exactly the predicates the emitter
 * supplies for an M0X0 block (D.l == 0 in this game, index_page_cross forced to
 * 0 because instr_runtime_charges() only emits the penalty when x_flag != 0).
 *
 * Build:
 *   SR=/Users/wee/Documents/work/snesrecomp
 *   cc -std=c99 -w -I $SR/runner/src/snes tests/cyc_model_diff.c \
 *      $SR/runner/src/snes/interp816.c -o tests/out/cyc_model_diff
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include "interp816.h"
#include "snes_cycles.h"

#define MEMSZ 0x1000000u
static uint8_t *MEM;
static uint8_t bus_read(void *m, uint32_t a)             { (void)m; return MEM[a & 0xFFFFFF]; }
static void    bus_write(void *m, uint32_t a, uint8_t v) { (void)m; MEM[a & 0xFFFFFF] = v; }
int interp816_opcode_hook(uint32_t addr) { (void)addr; return 0; }

static Interp816 *g_cpu;

/* One directed opcode run in native mode. dp/x/y seed the addressing state. */
static int run_one(const uint8_t *code, int len, int mf, int xf,
                   uint16_t dp, uint16_t x, uint16_t y, uint32_t ptr)
{
    memset(MEM, 0, MEMSZ);
    interp816_reset(g_cpu);
    memcpy(&MEM[0x8000], code, (size_t)len);
    /* indirect operands live at $00:$0010 (word) and $00:$0012 (bank byte) */
    MEM[0x0010] = (uint8_t)(ptr);      MEM[0x0011] = (uint8_t)(ptr >> 8);
    MEM[0x0012] = (uint8_t)(ptr >> 16);
    g_cpu->pc = 0x8000; g_cpu->k = 0;
    g_cpu->e = 0; g_cpu->mf = mf; g_cpu->xf = xf;
    g_cpu->dp = dp; g_cpu->x = x; g_cpu->y = y; g_cpu->db = 0;
    return interp816_runOpcode(g_cpu);
}

static int g_floor_sum, g_aot_sum;

static void one(const char *name, const uint8_t *code, int len, uint8_t op,
                int mf, int xf, uint16_t dp, uint16_t x, uint16_t y,
                uint32_t ptr, int aot_xcross)
{
    int floor = run_one(code, len, mf, xf, dp, x, y, ptr);
    /* What the AOT block charges for the very same execution: the emitter
       folds m/x statically, adds `if (cpu->D & 0xFF) +1` at runtime (D=0 here),
       and only ever emits an index-page-cross `+= 1` when x_flag != 0. */
    int aot = snes_instr_cpu_cycles(op, mf, xf, /*e*/0, /*dp_low_nonzero*/0,
                                    aot_xcross, /*branch_taken*/0,
                                    /*branch_page_cross*/0);
    g_floor_sum += floor; g_aot_sum += aot;
    printf("  %-26s op $%02X  floor=%-3d aot=%-3d  delta=%+d\n",
           name, op, floor, aot, floor - aot);
}

int main(void)
{
    MEM = malloc(MEMSZ);
    g_cpu = interp816_init(NULL, bus_read, bus_write);

    printf("== M0X0 (16-bit memory + 16-bit index): indexed READS ==\n");
    /* $1000 + small index: no page crossing in either case. */
    { uint8_t c[]={0xBD,0x00,0x10}; one("LDA $1000,X no-cross", c,3,0xBD,0,0,0,0x0005,0,0x1005,0); }
    { uint8_t c[]={0xBD,0x00,0x10}; one("LDA $1000,X CROSS",    c,3,0xBD,0,0,0,0x00F8,0,0x10F8,1); }
    { uint8_t c[]={0xB9,0x00,0x10}; one("LDA $1000,Y no-cross", c,3,0xB9,0,0,0,0,0x0005,0x1005,0); }
    { uint8_t c[]={0xB9,0x00,0x10}; one("LDA $1000,Y CROSS",    c,3,0xB9,0,0,0,0,0x00F8,0x10F8,1); }
    { uint8_t c[]={0xB1,0x10};      one("LDA ($10),Y no-cross", c,2,0xB1,0,0,0,0,0x0005,0x1005,0); }
    { uint8_t c[]={0xB1,0x10};      one("LDA ($10),Y CROSS",    c,2,0xB1,0,0,0,0,0x00F8,0x10F8,1); }
    { uint8_t c[]={0xB7,0x10};      one("LDA [$10],Y no-cross", c,2,0xB7,0,0,0,0,0x0005,0x1005,0); }
    { uint8_t c[]={0xB7,0x10};      one("LDA [$10],Y CROSS",    c,2,0xB7,0,0,0,0,0x00F8,0x10F8,0); }
    { uint8_t c[]={0x9D,0x00,0x10}; one("STA $1000,X CROSS",    c,3,0x9D,0,0,0,0x00F8,0,0x10F8,0); }

    printf("\n== M0X0: the opcode mix of the $80:9DE8 burst function ==\n");
    { uint8_t c[]={0xC6,0xEF};      one("DEC $EF  (dp,RMW)",   c,2,0xC6,0,0,0,0,0,0,0); }
    { uint8_t c[]={0xA9,0x0F,0x00}; one("LDA #$0F",            c,3,0xA9,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x85,0xEF};      one("STA $EF  (dp)",       c,2,0x85,0,0,0,0,0,0,0); }
    { uint8_t c[]={0xA4,0xE5};      one("LDY $E5  (dp)",       c,2,0xA4,0,0,0,0,0,0,0); }
    { uint8_t c[]={0xB7,0xE1};      one("LDA [$E1],Y",         c,2,0xB7,0,0,0,0,0,0,0x1005); }
    { uint8_t c[]={0xEB};           one("XBA",                 c,1,0xEB,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x85,0xF1};      one("STA $F1  (dp)",       c,2,0x85,0,0,0,0,0,0,0); }
    { uint8_t c[]={0xC8};           one("INY",                 c,1,0xC8,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x84,0xE5};      one("STY $E5  (dp)",       c,2,0x84,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x68};           one("PLA",                 c,1,0x68,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x06,0xF1};      one("ASL $F1  (dp,RMW)",   c,2,0x06,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x48};           one("PHA",                 c,1,0x48,0,0,0,0,0,0,0); }
    { uint8_t c[]={0x60};           one("RTS",                 c,1,0x60,0,0,0,0,0,0,0); }
    printf("  ------------------------------------------------------------\n");
    printf("  floor=%d  aot=%d  delta=%+d cycles per body pass\n",
           g_floor_sum, g_aot_sum, g_floor_sum - g_aot_sum);

    printf("\n== branch (BPL, native, taken vs not) ==\n");
    {   /* not taken: N=1 */
        memset(MEM,0,MEMSZ); interp816_reset(g_cpu);
        MEM[0x8000]=0x10; MEM[0x8001]=0x12; g_cpu->pc=0x8000; g_cpu->e=0;
        g_cpu->mf=0; g_cpu->xf=0; g_cpu->n=true;
        int f=interp816_runOpcode(g_cpu);
        int a=snes_instr_cpu_cycles(0x10,0,0,0,0,0,0,0);
        printf("  BPL not-taken               op $10  floor=%-3d aot=%-3d  delta=%+d\n",f,a,f-a);
    }
    {   /* taken: N=0 */
        memset(MEM,0,MEMSZ); interp816_reset(g_cpu);
        MEM[0x8000]=0x10; MEM[0x8001]=0x12; g_cpu->pc=0x8000; g_cpu->e=0;
        g_cpu->mf=0; g_cpu->xf=0; g_cpu->n=false;
        int f=interp816_runOpcode(g_cpu);
        int a=snes_instr_cpu_cycles(0x10,0,0,0,0,0,1,0);
        printf("  BPL taken                   op $10  floor=%-3d aot=%-3d  delta=%+d\n",f,a,f-a);
    }
    return 0;
}
