# round4_generated_sets.md
#
# what: what each seed actually changed in the generated program: which files, and which functions appeared
# how:  the archived generated sets (round4_gen_r4base.tar.gz, round4_gen_r4pair.tar.gz and tests/out/r4/gen_<variant>.tar.gz) unpacked and compared; function names read out of dispatch_v2.c
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

control generated set: 20 files, 38 dispatch function names

== r4clean: 5 file(s) differ, functions +4 / -0 (total 42)
   .snesrecomp-cache.json       8406 -> 8768 B
   bank80_v2.c                  2039681 -> 3372525 B
   bank81_part00_v2.c           327793 -> 431663 B
   dispatch_v2.c                31317 -> 33335 B
   program_manifest.json        228635 -> 248569 B
   new:  GS_80AAB3 GS_80ABBC GS_80B1DB GS_80C399
   GS_80AAB3 compiled mode variants: GS_80AAB3_M0X0
   GS_80ABBC compiled mode variants: GS_80ABBC_M0X0
   GS_80B1DB compiled mode variants: GS_80B1DB_M0X0
   GS_80C399 compiled mode variants: GS_80C399_M0X0
== r4pair: 5 file(s) differ, functions +2 / -0 (total 40)
   .snesrecomp-cache.json       8406 -> 8686 B
   bank80_v2.c                  2039681 -> 2615256 B
   bank81_part00_v2.c           327793 -> 431663 B
   dispatch_v2.c                31317 -> 32903 B
   program_manifest.json        228635 -> 240553 B
   new:  GS_80AAB3 GS_80C399
   GS_80AAB3 compiled mode variants: GS_80AAB3_M0X0
   GS_80C399 compiled mode variants: GS_80C399_M0X0
== s80AAB3: 5 file(s) differ, functions +1 / -0 (total 39)
   .snesrecomp-cache.json       8406 -> 8667 B
   bank80_v2.c                  2039681 -> 2592281 B
   bank81_part00_v2.c           327793 -> 431663 B
   dispatch_v2.c                31317 -> 32782 B
   program_manifest.json        228635 -> 239808 B
   new:  GS_80AAB3
   GS_80AAB3 compiled mode variants: GS_80AAB3_M0X0
== s80ABBC: 4 file(s) differ, functions +1 / -0 (total 39)
   .snesrecomp-cache.json       8406 -> 8425 B
   bank80_v2.c                  2039681 -> 2183890 B
   dispatch_v2.c                31317 -> 31438 B
   program_manifest.json        228635 -> 229051 B
   new:  GS_80ABBC
   GS_80ABBC compiled mode variants: GS_80ABBC_M0X0
== s80B1DB: 4 file(s) differ, functions +1 / -0 (total 39)
   .snesrecomp-cache.json       8406 -> 8469 B
   bank80_v2.c                  2039681 -> 2652741 B
   dispatch_v2.c                31317 -> 31628 B
   program_manifest.json        228635 -> 236235 B
   new:  GS_80B1DB
   GS_80B1DB compiled mode variants: GS_80B1DB_M0X0
== s80C399: 4 file(s) differ, functions +1 / -0 (total 39)
   .snesrecomp-cache.json       8406 -> 8425 B
   bank80_v2.c                  2039681 -> 2062656 B
   dispatch_v2.c                31317 -> 31438 B
   program_manifest.json        228635 -> 229380 B
   new:  GS_80C399
   GS_80C399 compiled mode variants: GS_80C399_M0X0

==== manifest node delta
control program: 269 nodes (aot_eligible 226, lle_only 43)

== r4base: 269 nodes (+0), removed 0, changed 0
== r4clean: 287 nodes (+18), removed 0, changed 0
   + 8080B2:M0X0    aot_eligible   69 insns  $8080B2-$808132
   + 808133:M0X0    aot_eligible   69 insns  $808133-$8081B3
   + 8081B4:M0X0    aot_eligible   72 insns  $8081B4-$808237
   + 808238:M0X0    aot_eligible   72 insns  $808238-$8082BB
   + 8082BC:M0X0    aot_eligible   93 insns  $8082BC-$808370
   + 80AA97:M0X0    aot_eligible   15 insns  $80AA97-$80AAB2
   + 80AAB3:M0X0    aot_eligible  108 insns  $80AAB3-$80ABBB
   + 80ABBC:M0X0    aot_eligible  196 insns  $80ABBC-$80AD80
   + 80B101:M0X0    aot_eligible   44 insns  $80B101-$80B15A
   + 80B1DB:M0X0    aot_eligible  756 insns  $80B1DB-$80B82E
   + 80C399:M0X0    aot_eligible   26 insns  $80C399-$80C3D0
   + 80C7DC:M0X0    aot_eligible   29 insns  $80C7DC-$80C81C
   + 80C81D:M0X0    aot_eligible   78 insns  $80C81D-$80C8E2
   + 80C8E3:M0X0    aot_eligible   91 insns  $80C8E3-$80C9AF
   + 80C9B0:M0X0    aot_eligible    7 insns  $80C9B0-$80C9C0
   + 8185FE:M0X0    aot_eligible   64 insns  $8185FE-$818684
   + 818686:M0X0    aot_eligible   47 insns  $818686-$8186E4
   + 8186E5:M0X0    aot_eligible   14 insns  $8186E5-$818700
== r4f362: 345 nodes (+76), removed 0, changed 0
   + 80C33A:M0X0    aot_eligible   19 insns  $80C33A-$80C365
   + 80F35D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F362:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F36B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F37B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F383:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F390:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3A1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3B4:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3C0:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3D2:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3EA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3F8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F400:M0X0    lle_only      729 insns  $80F353-$80F91C
   + 80F406:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F40C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F41E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F42A:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F485:M0X0    aot_eligible   20 insns  $80F485-$80F91C
   + 80F488:M0X0    aot_eligible    7 insns  $80F488-$80F494
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
   + 80F4FC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F505:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F510:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F520:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F530:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F54B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F596:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5A8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F644:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F653:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F660:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F678:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6BE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6C7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6DF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6E7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6EF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6F7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6FF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F70F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F72C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F73E:M0X0    aot_eligible   20 insns  $80F73E-$80F91C
   + 80F744:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F753:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F76F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F780:M0X0    aot_eligible   20 insns  $80F780-$80F91C
   + 80F786:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F795:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7B1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7C2:M0X0    aot_eligible   20 insns  $80F7C2-$80F91C
   + 80F7C8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7D8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7F5:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F807:M0X0    aot_eligible   20 insns  $80F807-$80F91C
   + 80F80D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F81C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F838:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F849:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F858:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F874:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F885:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F889:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F895:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F89E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8BB:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8CC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8D9:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8F1:M0X0    aot_eligible   19 insns  $80F8F1-$80F91C
== r4pair: 283 nodes (+14), removed 0, changed 0
   + 8080B2:M0X0    aot_eligible   69 insns  $8080B2-$808132
   + 808133:M0X0    aot_eligible   69 insns  $808133-$8081B3
   + 8081B4:M0X0    aot_eligible   72 insns  $8081B4-$808237
   + 808238:M0X0    aot_eligible   72 insns  $808238-$8082BB
   + 8082BC:M0X0    aot_eligible   93 insns  $8082BC-$808370
   + 80AAB3:M0X0    aot_eligible  108 insns  $80AAB3-$80ABBB
   + 80C399:M0X0    aot_eligible   26 insns  $80C399-$80C3D0
   + 80C7DC:M0X0    aot_eligible   29 insns  $80C7DC-$80C81C
   + 80C81D:M0X0    aot_eligible   78 insns  $80C81D-$80C8E2
   + 80C8E3:M0X0    aot_eligible   91 insns  $80C8E3-$80C9AF
   + 80C9B0:M0X0    aot_eligible    7 insns  $80C9B0-$80C9C0
   + 8185FE:M0X0    aot_eligible   64 insns  $8185FE-$818684
   + 818686:M0X0    aot_eligible   47 insns  $818686-$8186E4
   + 8186E5:M0X0    aot_eligible   14 insns  $8186E5-$818700
== r4probe: 270 nodes (+1), removed 0, changed 0
   + 81B061:M0X0    aot_eligible    3 insns  $81B061-$81B067
== s80AAB3: 282 nodes (+13), removed 0, changed 0
   + 8080B2:M0X0    aot_eligible   69 insns  $8080B2-$808132
   + 808133:M0X0    aot_eligible   69 insns  $808133-$8081B3
   + 8081B4:M0X0    aot_eligible   72 insns  $8081B4-$808237
   + 808238:M0X0    aot_eligible   72 insns  $808238-$8082BB
   + 8082BC:M0X0    aot_eligible   93 insns  $8082BC-$808370
   + 80AAB3:M0X0    aot_eligible  108 insns  $80AAB3-$80ABBB
   + 80C7DC:M0X0    aot_eligible   29 insns  $80C7DC-$80C81C
   + 80C81D:M0X0    aot_eligible   78 insns  $80C81D-$80C8E2
   + 80C8E3:M0X0    aot_eligible   91 insns  $80C8E3-$80C9AF
   + 80C9B0:M0X0    aot_eligible    7 insns  $80C9B0-$80C9C0
   + 8185FE:M0X0    aot_eligible   64 insns  $8185FE-$818684
   + 818686:M0X0    aot_eligible   47 insns  $818686-$8186E4
   + 8186E5:M0X0    aot_eligible   14 insns  $8186E5-$818700
== s80ABBC: 270 nodes (+1), removed 0, changed 0
   + 80ABBC:M0X0    aot_eligible  196 insns  $80ABBC-$80AD80
== s80B1DB: 272 nodes (+3), removed 0, changed 0
   + 80AA97:M0X0    aot_eligible   15 insns  $80AA97-$80AAB2
   + 80B101:M0X0    aot_eligible   44 insns  $80B101-$80B15A
   + 80B1DB:M0X0    aot_eligible  756 insns  $80B1DB-$80B82E
== s80C1B3: 349 nodes (+80), removed 0, changed 0
   + 80C1B3:M0X0    lle_only        9 insns  $80C1B3-$80C1C8
   + 80C1C9:M0X0    lle_only       12 insns  $80C1C9-$80C208
   + 80C33A:M0X0    aot_eligible   19 insns  $80C33A-$80C365
   + 80C399:M0X0    aot_eligible   26 insns  $80C399-$80C3D0
   + 80F342:M0X0    lle_only      741 insns  $80F342-$80F91C
   + 80F35D:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F362:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F36B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F37B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F383:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F390:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3A1:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3AE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3B4:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3BA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3C0:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3D2:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3EA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3F8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F400:M0X0    lle_only      734 insns  $80F353-$80F91C
   + 80F406:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F40C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F41E:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F42A:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F485:M0X0    aot_eligible   20 insns  $80F485-$80F91C
   + 80F488:M0X0    aot_eligible    7 insns  $80F488-$80F494
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
   + 80F4FC:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F505:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F510:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F520:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F530:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F54B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F596:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5A8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5BA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5D3:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F644:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F653:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F660:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F678:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6BE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6C7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6D3:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6DF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6E7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6EF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6F7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6FF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F70F:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F72C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F73E:M0X0    aot_eligible   20 insns  $80F73E-$80F91C
   + 80F744:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F753:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F76F:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F780:M0X0    aot_eligible   20 insns  $80F780-$80F91C
   + 80F786:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F795:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7B1:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7C2:M0X0    aot_eligible   20 insns  $80F7C2-$80F91C
   + 80F7C8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7D8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7F5:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F807:M0X0    aot_eligible   20 insns  $80F807-$80F91C
   + 80F80D:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F81C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F838:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F849:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F858:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F874:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F885:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F889:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F895:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F89E:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8AE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8BB:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8CC:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8D9:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8F1:M0X0    aot_eligible   19 insns  $80F8F1-$80F91C
== s80C1C9: 348 nodes (+79), removed 0, changed 0
   + 80C1C9:M0X0    lle_only       12 insns  $80C1C9-$80C208
   + 80C33A:M0X0    aot_eligible   19 insns  $80C33A-$80C365
   + 80C399:M0X0    aot_eligible   26 insns  $80C399-$80C3D0
   + 80F342:M0X0    lle_only      741 insns  $80F342-$80F91C
   + 80F35D:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F362:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F36B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F37B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F383:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F390:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3A1:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3AE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3B4:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3BA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3C0:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3D2:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3EA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F3F8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F400:M0X0    lle_only      734 insns  $80F353-$80F91C
   + 80F406:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F40C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F41E:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F42A:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F485:M0X0    aot_eligible   20 insns  $80F485-$80F91C
   + 80F488:M0X0    aot_eligible    7 insns  $80F488-$80F494
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
   + 80F4FC:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F505:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F510:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F520:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F530:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F54B:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F596:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5A8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5BA:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F5D3:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F644:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F653:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F660:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F678:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6BE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6C7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6D3:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6DF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6E7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6EF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6F7:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F6FF:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F70F:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F72C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F73E:M0X0    aot_eligible   20 insns  $80F73E-$80F91C
   + 80F744:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F753:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F76F:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F780:M0X0    aot_eligible   20 insns  $80F780-$80F91C
   + 80F786:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F795:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7B1:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7C2:M0X0    aot_eligible   20 insns  $80F7C2-$80F91C
   + 80F7C8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7D8:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F7F5:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F807:M0X0    aot_eligible   20 insns  $80F807-$80F91C
   + 80F80D:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F81C:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F838:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F849:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F858:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F874:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F885:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F889:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F895:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F89E:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8AE:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8BB:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8CC:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8D9:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F8F1:M0X0    aot_eligible   19 insns  $80F8F1-$80F91C
== s80C399: 270 nodes (+1), removed 0, changed 0
   + 80C399:M0X0    aot_eligible   26 insns  $80C399-$80C3D0
== s80F362: 345 nodes (+76), removed 0, changed 0
   + 80C33A:M0X0    aot_eligible   19 insns  $80C33A-$80C365
   + 80F35D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F362:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F36B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F37B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F383:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F390:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3A1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3B4:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3C0:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3D2:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3EA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3F8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F400:M0X0    lle_only      729 insns  $80F353-$80F91C
   + 80F406:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F40C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F41E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F42A:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F485:M0X0    aot_eligible   20 insns  $80F485-$80F91C
   + 80F488:M0X0    aot_eligible    7 insns  $80F488-$80F494
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
   + 80F4FC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F505:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F510:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F520:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F530:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F54B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F596:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5A8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F644:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F653:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F660:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F678:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6BE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6C7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6DF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6E7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6EF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6F7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6FF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F70F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F72C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F73E:M0X0    aot_eligible   20 insns  $80F73E-$80F91C
   + 80F744:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F753:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F76F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F780:M0X0    aot_eligible   20 insns  $80F780-$80F91C
   + 80F786:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F795:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7B1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7C2:M0X0    aot_eligible   20 insns  $80F7C2-$80F91C
   + 80F7C8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7D8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7F5:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F807:M0X0    aot_eligible   20 insns  $80F807-$80F91C
   + 80F80D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F81C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F838:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F849:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F858:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F874:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F885:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F889:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F895:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F89E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8BB:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8CC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8D9:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8F1:M0X0    aot_eligible   19 insns  $80F8F1-$80F91C
== s80F495: 271 nodes (+2), removed 0, changed 0
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
== s80F4F9: 270 nodes (+1), removed 0, changed 0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
== s80F889: 345 nodes (+76), removed 0, changed 0
   + 80C33A:M0X0    aot_eligible   19 insns  $80C33A-$80C365
   + 80F35D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F362:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F36B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F37B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F383:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F390:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3A1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3B4:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3C0:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3D2:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3EA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F3F8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F400:M0X0    lle_only      729 insns  $80F353-$80F91C
   + 80F406:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F40C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F41E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F42A:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F485:M0X0    aot_eligible   20 insns  $80F485-$80F91C
   + 80F488:M0X0    aot_eligible    7 insns  $80F488-$80F494
   + 80F495:M0X0    lle_only       32 insns  $80F495-$80F4D0
   + 80F4F9:M0X0    aot_eligible    1 insns  $80F4F9-$80F4F9
   + 80F4FC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F505:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F510:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F520:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F530:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F54B:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F596:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5A8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5BA:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F5D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F644:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F653:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F660:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F678:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6BE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6C7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6D3:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6DF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6E7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6EF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6F7:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F6FF:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F70F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F72C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F73E:M0X0    aot_eligible   20 insns  $80F73E-$80F91C
   + 80F744:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F753:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F76F:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F780:M0X0    aot_eligible   20 insns  $80F780-$80F91C
   + 80F786:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F795:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7B1:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7C2:M0X0    aot_eligible   20 insns  $80F7C2-$80F91C
   + 80F7C8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7D8:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F7F5:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F807:M0X0    aot_eligible   20 insns  $80F807-$80F91C
   + 80F80D:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F81C:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F838:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F849:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F858:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F874:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F885:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F889:M0X0    lle_only      731 insns  $80F353-$80F91C
   + 80F895:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F89E:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8AE:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8BB:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8CC:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8D9:M0X0    lle_only      726 insns  $80F353-$80F91C
   + 80F8F1:M0X0    aot_eligible   19 insns  $80F8F1-$80F91C
