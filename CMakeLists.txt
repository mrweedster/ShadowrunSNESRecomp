cmake_minimum_required(VERSION 3.20)
project(ShadowrunSNESRecomp C CXX)

set(CMAKE_C_STANDARD 11)

# Release pin for lobby matching. Release builds stamp the VERSION file so two
# peers can prove they are the same build; everything else stamps "dev".
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" _GAME_VER_RAW)
string(STRIP "${_GAME_VER_RAW}" GAME_RELEASE_VERSION)
set(SNESRECOMP_BUILD_VERSION "" CACHE STRING
    "Lobby release pin (empty = Release uses VERSION, else dev)")
if(SNESRECOMP_BUILD_VERSION STREQUAL "")
    get_property(_is_multi GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(_is_multi)
        set(SNESRECOMP_BUILD_VERSION "$<IF:$<CONFIG:Release>,${GAME_RELEASE_VERSION},dev>")
    elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
        set(SNESRECOMP_BUILD_VERSION "${GAME_RELEASE_VERSION}")
    else()
        set(SNESRECOMP_BUILD_VERSION "dev")
    endif()
endif()

set(SNESRECOMP_ROOT "${CMAKE_SOURCE_DIR}/snesrecomp" CACHE PATH
    "Path to the snesrecomp checkout used by this game")
# The presets pass $env{SNESRECOMP_ROOT}: an unset variable would otherwise
# become an empty cache entry and turn the check below into "/runner/runner.cmake".
if(SNESRECOMP_ROOT STREQUAL "")
    set(SNESRECOMP_ROOT "${CMAKE_SOURCE_DIR}/snesrecomp" CACHE PATH
        "Path to the snesrecomp checkout used by this game" FORCE)
endif()
if(NOT EXISTS "${SNESRECOMP_ROOT}/runner/runner.cmake")
    message(FATAL_ERROR
        "snesrecomp not found at ${SNESRECOMP_ROOT}.\n"
        "Point the build at a framework checkout with "
        "-DSNESRECOMP_ROOT=/path/to/snesrecomp (or set the environment\n"
        "variable of that name), or add the submodule with: "
        "git submodule update --init --recursive")
endif()

# The mouse mod is split: the frame-space accessor and the OS-pointer hiding
# are framework code (runner/src/desktop/host_main.{c,h}), and this port calls
# them from src/mouse_cursor.c. An unpatched framework checkout configures and
# then fails at link with two undefined symbols; fail here instead, while the
# message can still name the file that fixes it.
file(READ "${SNESRECOMP_ROOT}/runner/src/desktop/host_main.h" _host_main_h)
string(FIND "${_host_main_h}" "snesrecomp_desktop_mouse_state" _mouse_api_at)
if(_mouse_api_at EQUAL -1)
    message(FATAL_ERROR
        "${SNESRECOMP_ROOT} is missing the mouse framework patch "
        "(snesrecomp_desktop_mouse_state).\n"
        "Apply tools/mouse_mod_framework.patch to that checkout (base "
        "32266300) or check out its mod/mouse branch:\n"
        "  git -C \"${SNESRECOMP_ROOT}\" apply "
        "\"${CMAKE_SOURCE_DIR}/tools/mouse_mod_framework.patch\"")
endif()

# Perf: a fetch used to decode the same ROM mapping twice -- once to classify
# the address as stable, once more inside cpu_read8 -> cart_getRomPtr -- and
# that pair is the interpreter's hottest path. The framework patch in
# tools/interp_fused_rom_read_framework.patch (commit ca5673cb, adapted to the
# pin) claims the immutable plain LoROM/HiROM case once. It is the port's
# largest guest-CPU win, so require it and turn it on by default; the
# framework's reference decoder stays selectable with
# -DSNESRECOMP_INTERP_READ_IMPL=REFERENCE.
if(NOT EXISTS "${SNESRECOMP_ROOT}/runner/src/cpu_plain_rom_read.h")
    message(FATAL_ERROR
        "${SNESRECOMP_ROOT} is missing the fused interpreter ROM read patch "
        "(runner/src/cpu_plain_rom_read.h).\n"
        "Apply tools/interp_fused_rom_read_framework.patch on top of the pin "
        "and the mouse/MSVC patches:\n"
        "  git -C \"${SNESRECOMP_ROOT}\" apply "
        "\"${CMAKE_SOURCE_DIR}/tools/interp_fused_rom_read_framework.patch\"")
endif()
if(NOT DEFINED SNESRECOMP_INTERP_READ_IMPL OR
   SNESRECOMP_INTERP_READ_IMPL STREQUAL "")
    set(SNESRECOMP_INTERP_READ_IMPL "FUSED" CACHE STRING
        "Interpreter ROM read decoding (REFERENCE or FUSED)" FORCE)
endif()

# ── ROM editions ────────────────────────────────────────────────────────────
# Shadowrun (USA), the German translation and the Swedish translation are
# three programs, not three revisions of one: the inserted text moved the code,
# so each needs its own recompiled tree, and the translations keep the hand
# cursor 0x1C lower in WRAM.
#
# This tree builds ONE executable that carries all three. The USA tree stays
# the stock, unprefixed program module; the translations are generated with
# --module-prefix so they can link beside it. At boot the host hands us the
# player's ROM and src/edition.c selects the module whose recorded digest
# matches it. A binary built this way accepts any of the editions it carries.
#
#   SHADOWRUN_EDITIONS=us;de;sv   (default) universal
#   SHADOWRUN_EDITIONS=us         USA only
#   SHADOWRUN_UNIVERSAL=OFF + SHADOWRUN_EDITION=de   one translation
#
# The digests live in rom_identity*.txt; tools/gen_editions.py turns them into
# the runtime table, and tools/regen-all-editions.sh generates all three trees.
set(SHADOWRUN_EDITIONS "us;de;sv" CACHE STRING
    "ROM editions linked into this executable (us, de, sv)")
set_property(CACHE SHADOWRUN_EDITIONS PROPERTY STRINGS
    "us;de;sv" "us;de" "us;sv" "de;sv" "us" "de" "sv")
option(SHADOWRUN_UNIVERSAL
    "Link every edition in SHADOWRUN_EDITIONS into one executable" ON)
set(SHADOWRUN_EDITION "us" CACHE STRING
    "ROM edition for a single-edition build (when SHADOWRUN_UNIVERSAL=OFF)")
set_property(CACHE SHADOWRUN_EDITION PROPERTY STRINGS us de sv)

if(NOT SHADOWRUN_UNIVERSAL)
    set(SHADOWRUN_EDITIONS "${SHADOWRUN_EDITION}")
endif()

set(_shadowrun_seen "")
set(_shadowrun_tags "")
set(_shadowrun_identities "")
set(_shadowrun_gen_dirs "")
foreach(_edition IN LISTS SHADOWRUN_EDITIONS)
    if(NOT _edition MATCHES "^(us|de|sv)$")
        message(FATAL_ERROR
            "SHADOWRUN_EDITIONS contains '${_edition}'; use us, de or sv.")
    endif()
    list(FIND _shadowrun_seen "${_edition}" _duplicate)
    if(NOT _duplicate EQUAL -1)
        message(FATAL_ERROR "SHADOWRUN_EDITIONS lists '${_edition}' twice.")
    endif()

    if(_edition STREQUAL "us")
        set(_edition_identity "rom_identity.txt")
        set(_edition_gen "src/gen")
    elseif(_edition STREQUAL "de")
        set(_edition_identity "rom_identity.de.txt")
        set(_edition_gen "src/gen-de")
    else()
        set(_edition_identity "rom_identity.sv.txt")
        set(_edition_gen "src/gen-sv")
    endif()

    list(APPEND _shadowrun_seen "${_edition}")
    list(APPEND _shadowrun_tags "${_edition}")
    list(APPEND _shadowrun_identities "${CMAKE_SOURCE_DIR}/${_edition_identity}")
    list(APPEND _shadowrun_gen_dirs "${CMAKE_SOURCE_DIR}/${_edition_gen}")
endforeach()

list(LENGTH _shadowrun_tags _shadowrun_edition_count)
if(_shadowrun_edition_count EQUAL 0)
    message(FATAL_ERROR "SHADOWRUN_EDITIONS is empty; use us, de or sv.")
endif()
list(GET _shadowrun_tags 0 _shadowrun_stock_edition)
list(GET _shadowrun_identities 0 _shadowrun_stock_identity)
list(GET _shadowrun_gen_dirs 0 _shadowrun_stock_gen)
if(_shadowrun_edition_count GREATER 1)
    set(_shadowrun_universal_build 1)
else()
    set(_shadowrun_universal_build 0)
endif()

message(STATUS "Shadowrun editions: ${_shadowrun_tags} "
               "(stock ${_shadowrun_stock_edition}, "
               "generated code ${_shadowrun_stock_gen})")

# Mod packages are part of every project, not an option. The launcher's Mods
# page, the .snesmod loader, the trusted-plugin registry and netplay's mod-set
# gate all hang off this one switch; a build without it cannot exchange mods
# with a peer that has them, and the framework says so at every lobby init.
# Must precede the include: runner.cmake reads it to add the loader sources.
set(SNESRECOMP_ENABLE_MODS ON CACHE BOOL
    "Mod package loader + trusted plugins (required for every title)" FORCE)
include(${SNESRECOMP_ROOT}/runner/runner.cmake)

# ── The runtime edition table ──────────────────────────────────────────────
# src/edition.c matches the ROM it is handed against the generated module's
# recorded digest. The table it uses (tags, digests, cursor words, save roots)
# is generated from the identity files so a digest bump stays one edit there.
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(_shadowrun_editions_data
    "${CMAKE_CURRENT_BINARY_DIR}/shadowrun_editions_data.c")
set(_shadowrun_edition_args "")
set(_shadowrun_index 0)
foreach(_identity IN LISTS _shadowrun_identities)
    list(GET _shadowrun_tags ${_shadowrun_index} _tag)
    list(APPEND _shadowrun_edition_args --edition "${_tag}=${_identity}")
    math(EXPR _shadowrun_index "${_shadowrun_index}+1")
endforeach()
execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/tools/gen_editions.py"
            ${_shadowrun_edition_args}
            --stock "${_shadowrun_stock_edition}"
            --out "${_shadowrun_editions_data}"
    RESULT_VARIABLE _shadowrun_editions_rc
    OUTPUT_VARIABLE _shadowrun_editions_out
    ERROR_VARIABLE _shadowrun_editions_err)
if(NOT _shadowrun_editions_rc EQUAL 0)
    message(FATAL_ERROR
        "tools/gen_editions.py failed (${_shadowrun_editions_rc}):\n"
        "${_shadowrun_editions_err}")
endif()
string(STRIP "${_shadowrun_editions_out}" _shadowrun_editions_out)
if(_shadowrun_editions_out)
    message(STATUS "${_shadowrun_editions_out}")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    ${_shadowrun_identities}
    "${CMAKE_SOURCE_DIR}/tools/gen_editions.py")

add_executable(ShadowrunSNESRecomp
    ${SNESRECOMP_RUNNER_SOURCES}
    src/main.c
    src/edition.c
    ${_shadowrun_editions_data}
    src/host_contract.c
    src/game_rtl.c
    src/mouse_cursor.c
    src/gen_stubs.c
)

# Windows builds are MSVC (Visual Studio 2022). The sources and generated C are
# UTF-8, and MSVC otherwise reads them in the system code page (C4819, and
# mangled non-ASCII literals). The generated translation units use CRT
# functions MSVC marks deprecated; that is not an error here, but the warnings
# would bury real ones from the hand-written host code.
if(MSVC)
    target_compile_options(ShadowrunSNESRecomp PRIVATE /utf-8)
    target_compile_definitions(ShadowrunSNESRecomp PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# ROM identity. rom_identity*.txt is the one place each edition's digests
# live: the build turns the stock edition's file into
# snesrecomp_rom_identity.h for src/main.c, and tools/regen.sh,
# tools/gen_editions.py, scripts/package_release.sh and the release workflow
# read the same files. A revision bump is one edit there. In a universal build
# src/main.c deliberately does not hand the single expected digest to the
# framework host; src/edition.c matches the ROM against all linked modules.
snesrecomp_rom_identity(ShadowrunSNESRecomp ${_shadowrun_stock_identity})

# Generated recompiler output. Not committed: it is derived from a copyrighted
# ROM, so every developer regenerates it locally from their own copy -- and a
# release does not ship it either. With -DSNESRECOMP_SETUP_HOST=ON and empty
# generated directories, this builds the SETUP HOST instead: the same
# executable minus the recompiled code, whose only path is the launcher's
# Generate & rebuild wizard. Without the option an empty stock tree is still a
# hard error (the framework owns the message).
#
# The stock edition's tree is normally unprefixed (module id "main"). Every
# additional edition is a prefixed program module; tools/regen-all-editions.sh
# generates the translations that way. A single-edition translation build may
# use a prefixed tree too -- the block below aliases the framework's stock
# symbols when it does. One executable, one dispatch table selected at boot
# from the ROM's digest.
#
# A fresh clone has none of those trees, and the framework's own "src/gen is
# empty" message only names the single-edition regen. Name the port's command
# first so a first build from a clone is one error, not a hunt.
if(NOT SNESRECOMP_SETUP_HOST)
    set(_shadowrun_missing_gen "")
    foreach(_shadowrun_gen IN LISTS _shadowrun_gen_dirs)
        file(GLOB _shadowrun_gen_c "${_shadowrun_gen}/*.c")
        if(NOT _shadowrun_gen_c)
            list(APPEND _shadowrun_missing_gen "${_shadowrun_gen}")
        endif()
    endforeach()
    if(_shadowrun_missing_gen)
        string(REPLACE ";" "\n  " _shadowrun_missing_gen_text
               "${_shadowrun_missing_gen}")
        message(FATAL_ERROR
            "No generated code in:\n  ${_shadowrun_missing_gen_text}\n"
            "Generated trees are derived from the ROM and are not committed. "
            "With your own dumps:\n"
            "  bash tools/regen-all-editions.sh --rom-dir /path/to/dumps\n"
            "or one edition:\n"
            "  ROM=/path/to/shadowrun.sfc bash tools/regen.sh\n"
            "Then re-run this configure. BUILDING.md has the full sequence.")
    endif()
endif()
snesrecomp_target_generated_code(ShadowrunSNESRecomp ${_shadowrun_stock_gen})
if(_shadowrun_edition_count GREATER 1)
    if(SNESRECOMP_SETUP_HOST)
        message(STATUS
            "SETUP HOST: ${_shadowrun_edition_count} editions requested; only the "
            "stock dispatch is linked, so a Generate & rebuild produces one edition")
    else()
        math(EXPR _shadowrun_last "${_shadowrun_edition_count} - 1")
        foreach(_shadowrun_index RANGE 1 ${_shadowrun_last})
            list(GET _shadowrun_tags ${_shadowrun_index} _tag)
            list(GET _shadowrun_gen_dirs ${_shadowrun_index} _gen)
            snesrecomp_target_program_module(ShadowrunSNESRecomp "${_gen}")
            message(STATUS "Shadowrun edition ${_tag}: program module from ${_gen}")
        endforeach()
    endif()
endif()

# The mod catalog. This names WHERE the packages are; the framework owns the
# layout they are staged into beside the executable, and stages them on every
# build OF THE EXECUTABLE -- including the launcher's own Generate & rebuild on
# a player's machine, which builds only this target and would skip a sibling
# ALL target. mods/preloaded/packages/ holds reviewed, default-disabled
# packages; players install .snesmod archives through the launcher.
# snesrecomp/docs/MOD_PACKAGES.md.
#
# It used to be `snesrecomp_target_stage_dir(... ${CMAKE_SOURCE_DIR}/mods mods)`
# -- the destination spelled per title, which is how three ports in the same
# workspace ended up shipping an empty Mods page and nothing said so. Declaring
# it is now also enforced: a project with packages that never calls this fails
# to configure.
snesrecomp_target_mod_catalog(ShadowrunSNESRecomp ${CMAKE_SOURCE_DIR}/mods/preloaded)
# Any other directory the game reads exe-relative (a translations/ table, ...)
# is staged with snesrecomp_target_stage_dir, never with a separate ALL target.

target_include_directories(ShadowrunSNESRecomp PRIVATE
    ${SNESRECOMP_RUNNER_INCLUDE_DIRS}
    # common_rtl.c includes "config.h": the desktop key-map / Config contract
    # the framework host supplies (snesrecomp_target_desktop_host below).
    ${SNESRECOMP_ROOT}/runner/src/desktop
    ${CMAKE_SOURCE_DIR}/src
    # The stock edition's generated tree first: its funcs.h is the one this
    # build's hand-written host code includes. recomp/ keeps the USA copy for
    # the default build. Prefixed modules carry their own funcs.h beside their
    # generated C; their translation units include it directly.
    ${_shadowrun_stock_gen}
    ${CMAKE_SOURCE_DIR}/recomp
)
target_link_libraries(ShadowrunSNESRecomp PRIVATE ${SNESRECOMP_RUNNER_LIBRARIES})
target_compile_definitions(ShadowrunSNESRecomp PRIVATE
    SNES_GAME_VERSION="${SNESRECOMP_BUILD_VERSION}"
    SNES_GAME_TITLE="Shadowrun"
    SHADOWRUN_UNIVERSAL=${_shadowrun_universal_build}
)

# The framework links against the stock tree's unprefixed dispatch/guard
# symbols (g_dispatch_table and friends). A single-edition German or Swedish
# build can be generated either unprefixed (the old per-edition workflow) or
# with a module prefix (as the universal set's src/gen-de and src/gen-sv are).
# In the prefixed case point the framework's references at the same symbols
# the generated tree actually defines; module_namespace.h already renames
# every reference inside the tree, so this only affects the runner's C.
if(NOT _shadowrun_universal_build)
    if(_shadowrun_stock_edition STREQUAL "de")
        set(_shadowrun_stock_prefix "shadowrun_de")
    elseif(_shadowrun_stock_edition STREQUAL "sv")
        set(_shadowrun_stock_prefix "shadowrun_sv")
    else()
        set(_shadowrun_stock_prefix "")
    endif()
    if(_shadowrun_stock_prefix AND
       EXISTS "${_shadowrun_stock_gen}/module_namespace.h")
        target_compile_definitions(ShadowrunSNESRecomp PRIVATE
            g_dispatch_table=${_shadowrun_stock_prefix}_g_dispatch_table
            g_dispatch_table_count=${_shadowrun_stock_prefix}_g_dispatch_table_count
            g_ram_routine_guards=${_shadowrun_stock_prefix}_g_ram_routine_guards
            g_ram_routine_guard_count=${_shadowrun_stock_prefix}_g_ram_routine_guard_count)
        message(STATUS
            "Shadowrun edition ${_shadowrun_stock_edition}: prefixed tree "
            "(${_shadowrun_stock_prefix}); aliasing the framework's stock symbols")
    endif()
endif()
snesrecomp_target_sdl(ShadowrunSNESRecomp)

# The desktop host: launcher flow, ROM resolution, config.ini + [KeyMap],
# window + SDL/OpenGL presenters, audio, gamepads, the save-state browser and
# rewind filmstrip, the pacing clock, crash handlers and the post-mortem
# report. src/main.c is the shim that names this title and supplies its
# hooks; the host is the framework's and improves on a submodule pull.
# Add TIER2 once this port reads the interpreter-gap manifest after each run.
snesrecomp_target_desktop_host(ShadowrunSNESRecomp)
# rom.cfg (the ROM the wizard set this project up from; git-ignored) is
# staged beside the executable when none is there yet, so the first launch
# opens on that dump rather than asking for one. A universal build has no
# single default dump -- it stages nothing and resolves --rom/rom.cfg/the
# host's usual order -- so only a USA-only build gets the cache.
if(_shadowrun_edition_count EQUAL 1 AND _shadowrun_stock_edition STREQUAL "us")
    snesrecomp_target_rom_cache(ShadowrunSNESRecomp)
endif()

# ── ROM-free build (stage-1 C0 / M3) ───────────────────────────────────────
# Off by default: the ROM-based build above stays the parity reference and
# every gate in tests/ runs against it. With this option the guest image is
# compiled into the executable, so the binary boots and plays from an empty
# directory -- no .sfc beside it, no rom.cfg, no launcher asking for a dump.
# The image goes in through tools/embed_rom.py, which checks it against
# rom_identity.txt before writing it, and the framework host re-hashes the
# embedded bytes at boot (SNESRECOMP_EMBEDDED_ROM) and exits rather than
# running machine code beside an image it was not generated from. So the two
# halves of the artefact cannot drift apart, and a wrong image stops the
# configure instead of producing a binary that refuses to start.
option(SHADOWRUN_EMBED_ROM "compile the ROM image into the executable (ROM-free build)" OFF)
if(SHADOWRUN_EMBED_ROM)
    if(_shadowrun_edition_count GREATER 1)
        message(FATAL_ERROR
            "SHADOWRUN_EMBED_ROM=ON bakes one image into the executable, so it "
            "cannot be a universal build.\nConfigure one edition instead:\n"
            "  -DSHADOWRUN_UNIVERSAL=OFF -DSHADOWRUN_EDITION=us|de|sv")
    endif()
    set(EMBED_ROM "" CACHE PATH
        "image to bake in (empty = the same search tools/regen.sh uses)")
    set(_embed_c    "${CMAKE_CURRENT_BINARY_DIR}/embedded_rom.c")
    set(_embed_frag "${CMAKE_CURRENT_BINARY_DIR}/embedded_rom.cmake")
    set(_embed_cmd "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tools/embed_rom.py"
        --out "${_embed_c}" --framework-root "${SNESRECOMP_ROOT}"
        --identity "${_shadowrun_stock_identity}")
    if(NOT EMBED_ROM STREQUAL "")
        list(APPEND _embed_cmd --rom "${EMBED_ROM}")
    endif()
    # Configure time, not build time: an embed build that cannot find its image
    # should fail where the message says what is missing, not at link. The array
    # is therefore rewritten whenever CMake re-runs -- which the config-depends
    # below arrange for if the image or the digest file changes. Editing the
    # generated array by hand and running `cmake --build` alone does not
    # re-trigger it; the host's boot-time digest check is what catches that.
    execute_process(COMMAND ${_embed_cmd} RESULT_VARIABLE _embed_rc
                    OUTPUT_VARIABLE _embed_out ERROR_VARIABLE _embed_err)
    if(NOT _embed_rc EQUAL 0)
        message(FATAL_ERROR
            "SHADOWRUN_EMBED_ROM=ON needs the guest image and cannot find it:\n"
            "${_embed_err}\nPass -DEMBED_ROM=\"/path/to/the "
            "${_shadowrun_stock_edition} dump\".")
    endif()
    string(STRIP "${_embed_out}" _embed_out)
    # The size and label the host's macros need come from the generator, so
    # CMake never re-parses rom_identity*.txt with a second parser.
    include("${_embed_frag}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${EMBED_ROM_PATH}" "${CMAKE_CURRENT_SOURCE_DIR}/tools/embed_rom.py"
        "${_shadowrun_stock_identity}")
    target_sources(ShadowrunSNESRecomp PRIVATE "${_embed_c}")
    target_compile_definitions(ShadowrunSNESRecomp PRIVATE
        SNESRECOMP_EMBEDDED_ROM
        SNESRECOMP_EMBEDDED_ROM_SIZE=${EMBED_ROM_SIZE}
        SNESRECOMP_EMBEDDED_ROM_NAME="${EMBED_ROM_NAME}")
    message(STATUS "ROM-free: ${_embed_out}")
endif()

# No GUI launcher: this project was scaffolded with --no-recomp-ui.
# Add the submodule and re-run this block to get one:
#   git submodule add https://github.com/mstan/recomp-ui.git recomp-ui
#   set(RECOMP_UI_ROOT "${CMAKE_SOURCE_DIR}/recomp-ui" CACHE PATH "" FORCE)
#   include(${RECOMP_UI_ROOT}/recomp_ui.cmake)
#   recomp_target_launcher_ui(ShadowrunSNESRecomp CONSOLE snes)

# Netplay is not built into this target.
# No multitap: two seats, one controller per port.
