# what the framework commits behind the shipped macOS packages are
# when: 2026-11-09T17:21:09Z
# how:  tests/macos_framework_commits.sh
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad

== 0. the three framework checkouts the shipped bytes came out of ==

  the directory is whatever SNESRECOMP_ROOT says in the CMakeCache.txt of the
  build tree named under it, so this is the checkout that supplied the code, not a
  checkout that happens to have the same history.  dirty is a line count of
  `git status --porcelain`: how many uncommitted paths the checkout holds.  0 is
  the condition every framework leg in this kit requires, because otherwise the
  bytes compiled are not the commit named.

  pin        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    HEAD 773285b8210f2254ae87d0a14113980fb36990ad  dirty 0
    AT THE PIN (commits past it: 0)

  shareable  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    HEAD 32266300d722b8b31cde3bbdc55614587f7653ae  dirty 0
    OFF THE PIN, pin is an ancestor, commits past it: 1

  personal   /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx
    HEAD a7fb67e6c9f5644a98ade281b6d157693a31eb52  dirty 0
    OFF THE PIN, pin is an ancestor, commits past it: 4

== 1. the two capability commits, found by subject ==

  each commit is located by grepping the subjects in pin..HEAD of the checkout that
  carries it, so the hash below is this round's reading of that branch rather than a
  number carried over from an older round.  The patch follows in full, so a code
  site quoted in prose can be found here by grep instead of taken on trust.

  --- embedded guest image
  c5024e74abef0d6b85913baffe8de124c5c7c299
  runner/desktop: boot an embedded guest image (SNESRECOMP_EMBEDDED_ROM)
  2026-11-06 16:10:40 +0100
  
   runner/src/desktop/host_main.c | 118 ++++++++++++++++++++++++++++++++++++++---
   1 file changed, 112 insertions(+), 6 deletions(-)

    full patch:
  diff --git a/runner/src/desktop/host_main.c b/runner/src/desktop/host_main.c
  index 997154c6..f9ee4b4b 100644
  --- a/runner/src/desktop/host_main.c
  +++ b/runner/src/desktop/host_main.c
  @@ -60,6 +60,7 @@
   #include "config.h"
   #include "display_aspect.h"
   #include "crc32.h"
  +#include "sha256.h"
   #include "util.h"
   #include "spc_player.h"
   #include "launcher.h"
  @@ -2708,6 +2709,9 @@ static uint32_t g_rom_crc32;
   static int g_rom_identity_ok;
   static const char *g_program_path;       /* argv[0]: keybinds.ini sits beside it */
   static const char *g_rom_path = "";      /* the running ROM, once resolved */
  +static int g_rom_embedded;               /* ...and it is this exe's own copy.
  +                                          * Not macro-gated: the restart path
  +                                          * below is the same code either way */
   
   /* The port's catalog of known dumps, plus a "<display_name> (<region>)" entry
    * for the generated-from ROM when the port's catalog does not list it. Built
  @@ -2715,6 +2719,59 @@ static const char *g_rom_path = "";      /* the running ROM, once resolved */
    * ROM from it. */
   static SnesRomRevision *g_rom_catalog;
   static int g_rom_catalog_count;
  +
  +/* ── Embedded ROM (opt-in: SNESRECOMP_EMBEDDED_ROM) ─────────────────────────
  + *
  + * A build that carries the guest image in its own data section needs no .sfc
  + * on disk at all. Three macro contracts, all supplied by the project's CMake
  + * (see the port's tools/embed_rom.py and CMakeLists.txt). Nothing here is
  + * wired unless SNESRECOMP_EMBEDDED_ROM is defined, so every build that does
  + * not ask for it is byte-for-byte the behaviour it had:
  + *
  + *   snesrecomp_embedded_rom[] / SNESRECOMP_EMBEDDED_ROM_SIZE
  + *                                the image bytes, exact, no SMC header
  + *   SNESRECOMP_EMBEDDED_ROM_NAME display name, for diagnostics only
  + *
  + * The digests this binary was configured with (rom_identity.txt) are checked
  + * against the embedded bytes before boot. A stale or mismatched embed is the
  + * one failure mode that would otherwise present as unexplainable in-game
  + * behaviour, so it is fatal here rather than advisory.
  + */
  +#if defined(SNESRECOMP_EMBEDDED_ROM)
  +#if !defined(SNESRECOMP_EMBEDDED_ROM_SIZE) || !defined(SNESRECOMP_EMBEDDED_ROM_NAME)
  +#error "SNESRECOMP_EMBEDDED_ROM needs SNESRECOMP_EMBEDDED_ROM_SIZE and SNESRECOMP_EMBEDDED_ROM_NAME"
  +#endif
  +/* Sized on purpose: a definition with a different element count is a compile
  + * error here, so the image can never disagree with the length this host
  + * passes to SnesInit. */
  +extern const unsigned char snesrecomp_embedded_rom[SNESRECOMP_EMBEDDED_ROM_SIZE];
  +
  +/* 1 = use the embedded image, 0 = no embed configured. Never fails silently:
  + * a mismatch is reported and the process exits. */
  +static int HostEmbeddedRomReady(void) {
  +  if (!g_rom_identity_ok)
  +    return 1;   /* the port declares no digests: same policy as the picker */
  +  const size_t n = (size_t)SNESRECOMP_EMBEDDED_ROM_SIZE;
  +  if (g_rom_crc32) {
  +    uint32_t got = crc32_compute(snesrecomp_embedded_rom, n);
  +    if (got != g_rom_crc32) {
  +      fprintf(stderr, "embedded ROM: crc32 %08X, but this build's machine code "
  +                      "was generated from %08X\n", got, g_rom_crc32);
  +      return -1;
  +    }
  +  }
  +  if (g_rom_sha256[0]) {
  +    uint8_t sha[32];
  +    sha256_compute(snesrecomp_embedded_rom, n, sha);
  +    if (memcmp(sha, g_rom_sha256, sizeof(sha)) != 0) {
  +      fprintf(stderr, "embedded ROM (%s): sha256 does not match the image this "
  +                      "build was generated from\n", SNESRECOMP_EMBEDDED_ROM_NAME);
  +      return -1;
  +    }
  +  }
  +  return 1;
  +}
  +#endif  /* SNESRECOMP_EMBEDDED_ROM */
   static char g_rom_fallback_label[160];
   
   static const char *HostRomHelp(void) {
  @@ -3236,8 +3293,14 @@ static void RunInGameLauncher(bool *running, const char **exit_reason) {
         /* Start again, from here. A different ROM is a different game, so it
          * starts from power-on; anything else resumes this exact frame. */
         bool same_rom = SameRomImage(rom, g_rom_path);
  -      snprintf(g_relaunch.rom, sizeof(g_relaunch.rom), "%s",
  -               rom[0] ? rom : g_rom_path);
  +      /* An embedded image has no path to hand the next process, and the label
  +       * in g_rom_path is a breadcrumb, not something to open. No --rom means
  +       * the new process resolves it the same way and finds its own copy. */
  +      g_relaunch.rom[0] = '\0';
  +      if (rom[0])
  +        snprintf(g_relaunch.rom, sizeof(g_relaunch.rom), "%s", rom);
  +      else if (!g_rom_embedded)
  +        snprintf(g_relaunch.rom, sizeof(g_relaunch.rom), "%s", g_rom_path);
         g_relaunch.with_state = false;
         if (same_rom &&
             snesrecomp_abspath("saves/resume.sav", g_relaunch.state,
  @@ -3507,6 +3570,26 @@ int snesrecomp_desktop_main(const SnesDesktopHostGame *game, int argc, char **ar
        * both spellings resolved and absolutized there. */
       const char *arg_rom = (args.rom && args.rom[0]) ? args.rom : NULL;
       int have_positional = (arg_rom != NULL);
  +#if defined(SNESRECOMP_EMBEDDED_ROM)
  +    /* The image is already inside this executable, so there is nothing to
  +     * resolve, no cache to consult and no picker to answer. An embed that
  +     * disagrees with this build's own digests is a broken artefact, so it is
  +     * fatal here rather than something to fall back from. An explicit --rom
  +     * still wins: the digests are checked on that path as on any other, which
  +     * also keeps a ROM-free binary usable as the control in a comparison run. */
  +    int embed_ready = HostEmbeddedRomReady();
  +    if (embed_ready < 0)
  +      return 1;
  +    if (embed_ready > 0 && !have_positional) {
  +      /* A label, not a path: it reaches breadcrumbs, the save-state header and
  +       * the MSU-1 path setter (a title with streamed MSU-1 media cannot be
  +       * embedded -- there is no file for that media to sit beside). */
  +      g_rom_embedded = 1;
  +      snprintf(rom_path_buf, sizeof(rom_path_buf), "<embedded:%s>",
  +               SNESRECOMP_EMBEDDED_ROM_NAME);
  +      goto rom_resolved;
  +    }
  +#endif
       if (!have_positional)
         FindRomBesideExe(beside_exe, sizeof(beside_exe));
   
  @@ -3638,6 +3721,7 @@ int snesrecomp_desktop_main(const SnesDesktopHostGame *game, int argc, char **ar
         }
       }
     }
  +rom_resolved:;
     static char *resolved_argv[2];
     resolved_argv[0] = rom_path_buf;
     resolved_argv[1] = NULL;
  @@ -3672,7 +3756,16 @@ int snesrecomp_desktop_main(const SnesDesktopHostGame *game, int argc, char **ar
     /* Resolve the enabled features against THIS ROM and persist the plan. A
      * rejected plan (wrong ROM for a package, a plugin nothing registered) is a
      * refusal, not a silent fallback. */
  -  if (g_mods_ready && !snes_mod_runtime_commit_c(rom_path_buf)) {
  +  /* An embedded image has no file to re-open. Passing no path makes the commit
  +   * validate against the digest mod_runtime_initialize() was handed -- this
  +   * build's own sha256, which HostEmbeddedRomReady() has just confirmed the
  +   * embedded bytes hash to. The check is the same one, not a weaker one. */
  +#if defined(SNESRECOMP_EMBEDDED_ROM)
  +  const char *mod_rom = g_rom_embedded ? NULL : rom_path_buf;
  +#else
  +  const char *mod_rom = rom_path_buf;
  +#endif
  +  if (g_mods_ready && !snes_mod_runtime_commit_c(mod_rom)) {
       fprintf(stderr, "mods: plan rejected: %s\n", snes_mod_runtime_last_error_c());
       return 1;
     }
  @@ -3776,6 +3869,15 @@ int snesrecomp_desktop_main(const SnesDesktopHostGame *game, int argc, char **ar
     /* Load the SNES ROM. argv[0] is the resolved path. */
     uint8 *kRom = NULL;
     uint32 kRom_SIZE = 0;
  +#if defined(SNESRECOMP_EMBEDDED_ROM)
  +  /* The embed was already hashed against this build's digests when the ROM was
  +   * resolved; booting those bytes needs no file. With --rom given, argv[0] is
  +   * a real path and the normal load below runs, digest-checked like any dump. */
  +  if (g_rom_embedded) {
  +    kRom = (uint8 *)snesrecomp_embedded_rom;
  +    kRom_SIZE = (uint32)SNESRECOMP_EMBEDDED_ROM_SIZE;
  +  } else
  +#endif
     if (argv[0]) {
       size_t size;
       kRom = ReadWholeFile(argv[0], &size);
  @@ -4601,7 +4703,9 @@ error_reading:;
     if (g_netplay_from_lobby && snes_netplay_return_to_lobby_requested()) {
       g_relaunch.pending = g_relaunch.launcher = true;
       g_relaunch.with_state = false;
  -    snprintf(g_relaunch.rom, sizeof(g_relaunch.rom), "%s", g_rom_path);
  +    g_relaunch.rom[0] = '\0';
  +    if (!g_rom_embedded)
  +      snprintf(g_relaunch.rom, sizeof(g_relaunch.rom), "%s", g_rom_path);
     }
     snes_netplay_shutdown();
     snes_host_lobby_shutdown();
  @@ -4644,8 +4748,10 @@ error_reading:;
         relaunch_args[n++] = "--resume-state";
         relaunch_args[n++] = g_relaunch.state;
       }
  -    relaunch_args[n++] = "--rom";
  -    relaunch_args[n++] = g_relaunch.rom;
  +    if (g_relaunch.rom[0]) {
  +      relaunch_args[n++] = "--rom";
  +      relaunch_args[n++] = g_relaunch.rom;
  +    }
       if (!snesrecomp_host_relaunch(n, relaunch_args)) {
         host_report_breadcrumb("in-game launcher: restart FAILED; start the game again");
         return 1;

  --- state out of the bundle
  32266300d722b8b31cde3bbdc55614587f7653ae
  runner/macos: keep writable state out of the .app bundle
  2026-11-09 10:56:32 +0100
  
   runner/src/desktop/host_main.c |  12 +++-
   runner/src/host_paths.c        | 130 +++++++++++++++++++++++++++++++++++++++++
   runner/src/host_paths.h        |   9 +++
   runner/src/keybinds.c          |  19 +++++-
   runner/src/launcher_cache.c    |   5 +-
   5 files changed, 169 insertions(+), 6 deletions(-)

    full patch:
  diff --git a/runner/src/desktop/host_main.c b/runner/src/desktop/host_main.c
  index 997154c6..08619c6b 100644
  --- a/runner/src/desktop/host_main.c
  +++ b/runner/src/desktop/host_main.c
  @@ -3477,12 +3477,18 @@ int snesrecomp_desktop_main(const SnesDesktopHostGame *game, int argc, char **ar
     /* Mod source-ROM pickers name a wrong ROM from the same catalog. */
     snes_mod_runtime_set_rom_catalog_c(g_rom_catalog, g_rom_catalog_count);
     /* Before the launcher, which needs the provider to show the Mods page.
  -   * The catalog is mods/preloaded beside the executable, staged by the build;
  -   * an empty one is valid. */
  +   * The catalog is mods/preloaded, staged beside the executable by the build;
  +   * an empty one is valid. It is written to -- the runtime keeps state.toml
  +   * there and installed .snesmod archives land there -- so it is looked up in
  +   * the run's writable state directory: inside a macOS bundle that is outside
  +   * the .app, which keeps the bundle's seal valid and the player's mods across
  +   * an app update. Outside a bundle the lookup names the same directory as
  +   * before. */
     if (game->game_id && game->game_id[0]) {
       char mods_dir[1024];
       if (config_file) snprintf(mods_dir, sizeof(mods_dir), SNES_MOD_CATALOG_ROOT);
  -    if (config_file || snesrecomp_exe_dir_path(SNES_MOD_CATALOG_ROOT, mods_dir, sizeof(mods_dir))) {
  +    if (config_file ||
  +        snesrecomp_state_dir_path(SNES_MOD_CATALOG_ROOT, mods_dir, sizeof(mods_dir))) {
         g_mods_ready = snes_mod_runtime_initialize_c(
             mods_dir, game->game_id,
             game->expected_sha256_hex ? game->expected_sha256_hex : "");
  diff --git a/runner/src/host_paths.c b/runner/src/host_paths.c
  index 216a8ff1..9334e62e 100644
  --- a/runner/src/host_paths.c
  +++ b/runner/src/host_paths.c
  @@ -24,6 +24,9 @@
   #endif
   #ifdef __APPLE__
   #  include <mach-o/dyld.h>
  +#  include <errno.h>
  +#  include <sys/stat.h>
  +#  include <sys/types.h>
   #endif
   
   /* Full path of the running executable. Returns 1 on success. Platforms
  @@ -75,6 +78,93 @@ static void get_exe_dir(char *out, size_t max_len) {
       snprintf(out, max_len, "./");
   }
   
  +#ifdef __APPLE__
  +/* ── macOS application bundles ──────────────────────────────────────────────
  + * A .app is meant to be a sealed, read-only unit. Once anything the program
  + * writes at run time lives inside it, the code seal stops matching the bytes on
  + * disk and macOS answers that the app "is damaged" whenever it re-assesses the
  + * copy: out of a disk image, after a download, or once App Translocation moves
  + * the running copy into a read-only mount. It also means replacing the app
  + * throws away the player's saves.
  + *
  + * So when the executable is running out of a bundle, writable state
  + * (config.ini, keybinds.ini, rom.cfg, saves/) belongs in
  + * ~/Library/Application Support/<bundle name>/ and read-only payload stays
  + * where it was staged. Outside a bundle nothing changes: the executable's own
  + * directory keeps both roles, which is how development trees and the test kit
  + * work, and they keep anchoring exactly as before.
  + */
  +
  +/* Directory holding the bundle's Contents, i.e. ".../Foo.app/Contents" for an
  + * executable at ".../Foo.app/Contents/MacOS/<name>". Uses the last match so a
  + * nested bundle's inner executable is described by its own bundle. Returns 0
  + * when the executable is not inside a bundle. */
  +static int get_bundle_contents_dir(char *out, size_t max_len) {
  +    char exe_path[1024];
  +    if (!get_exe_path(exe_path, sizeof(exe_path))) return 0;
  +    const char *mark = NULL;
  +    for (const char *p = exe_path; *p; p++)
  +        if (strncmp(p, "/Contents/MacOS/", 16) == 0) mark = p;
  +    if (!mark) return 0;
  +    size_t len = (size_t)(mark - exe_path);
  +    if (len + 10 >= max_len) return 0;
  +    memcpy(out, exe_path, len);
  +    out[len] = '\0';
  +    return 1;
  +}
  +
  +/* Create `path` together with any missing parent directories. */
  +static int mkdir_parents(const char *path) {
  +    char tmp[1024];
  +    if (snprintf(tmp, sizeof(tmp), "%s", path) >= (int)sizeof(tmp)) return 0;
  +    size_t len = strlen(tmp);
  +    while (len > 1 && tmp[len - 1] == '/') tmp[--len] = '\0';
  +    for (char *p = tmp + 1; *p; p++) {
  +        if (*p != '/') continue;
  +        *p = '\0';
  +        if (mkdir(tmp, 0777) != 0 && errno != EEXIST) return 0;
  +        *p = '/';
  +    }
  +    if (mkdir(tmp, 0777) != 0 && errno != EEXIST) return 0;
  +    return 1;
  +}
  +
  +/* The bundle's own name without the ".app" suffix, so two bundles never share
  + * one config directory. Returns "" semantics: 0 on failure. */
  +static int get_bundle_name(char *out, size_t max_len) {
  +    char contents[1024];
  +    if (!get_bundle_contents_dir(contents, sizeof(contents))) return 0;
  +    char *slash = NULL;
  +    for (char *p = contents; *p; p++)
  +        if (*p == '/') slash = p;
  +    if (!slash) return 0;
  +    const char *base = slash + 1;
  +    size_t len = strlen(base);
  +    if (len > 4 && strcmp(base + len - 4, ".app") == 0) len -= 4;
  +    if (!len) return 0;
  +    if (len >= max_len) return 0;
  +    memcpy(out, base, len);
  +    out[len] = '\0';
  +    return 1;
  +}
  +
  +/* Writable state directory for a bundled run, with trailing separator. Creates
  + * it, because every caller needs it to exist in order to write anything.
  + * Returns 0 when this is not a bundled run, $HOME is unset, or the directory
  + * cannot be created -- callers then keep the pre-bundle behaviour. */
  +static int get_state_dir(char *out, size_t max_len) {
  +    const char *home = getenv("HOME");
  +    if (!home || !home[0]) return 0;
  +    char name[256];
  +    if (!get_bundle_name(name, sizeof(name))) return 0;
  +    if (snprintf(out, max_len, "%s/Library/Application Support/%s/", home, name)
  +            >= (int)max_len)
  +        return 0;
  +    if (!mkdir_parents(out)) return 0;
  +    return 1;
  +}
  +#endif /* __APPLE__ */
  +
   int snesrecomp_abspath(const char *path, char *out, size_t max_len) {
       if (!path || !*path || !out || max_len == 0) return 0;
   #ifdef _WIN32
  @@ -141,6 +231,23 @@ int snesrecomp_exe_dir_path(const char *leaf, char *out, size_t max_len) {
       return 1;
   }
   
  +/* Writable counterpart of snesrecomp_exe_dir_path(): the same leaf, but in the
  + * directory this run is allowed to write into. For a macOS bundle that is
  + * ~/Library/Application Support/<bundle name>/, so config.ini, keybinds.ini and
  + * rom.cfg never land inside the sealed .app; everywhere else it is the
  + * executable's directory, exactly as before. */
  +int snesrecomp_state_dir_path(const char *leaf, char *out, size_t max_len) {
  +    if (!leaf || !out || max_len == 0) return 0;
  +#ifdef __APPLE__
  +    char dir[1024];
  +    if (get_state_dir(dir, sizeof(dir))) {
  +        if (snprintf(out, max_len, "%s%s", dir, leaf) >= (int)max_len) return 0;
  +        return 1;
  +    }
  +#endif
  +    return snesrecomp_exe_dir_path(leaf, out, max_len);
  +}
  +
   /* Probe by creating a file: access(W_OK) is unreliable on Windows and inside
    * sandboxed mounts. */
   static int dir_is_writable(const char *dir) {
  @@ -156,6 +263,29 @@ static int dir_is_writable(const char *dir) {
   }
   
   int snesrecomp_anchor_to_exe_dir(void) {
  +#ifdef __APPLE__
  +    /* Bundled run: anchor to the writable state directory instead, so every
  +     * relative path the host uses -- saves/, config.ini, the keybinds file it
  +     * rewrites, last_run_report.json -- lands outside the .app and the bundle's
  +     * code seal stays valid. */
  +    char state[1024];
  +    if (get_state_dir(state, sizeof(state))) {
  +        if (!dir_is_writable(state)) {
  +            fprintf(stderr,
  +                    "[Launcher] State directory '%s' is not writable; "
  +                    "config and saves stay in the current directory.\n", state);
  +            return 0;
  +        }
  +        if (snesrecomp_chdir(state) == 0) {
  +            fprintf(stderr,
  +                    "[Launcher] Config/saves anchored to '%s' "
  +                    "(bundle run: state kept outside the .app).\n", state);
  +            return 1;
  +        }
  +        fprintf(stderr, "[Launcher] Could not change directory to '%s'.\n", state);
  +        return 0;
  +    }
  +#endif
       char dir[1024];
       get_exe_dir(dir, sizeof(dir));
       if (dir[0] == '.' &&
  diff --git a/runner/src/host_paths.h b/runner/src/host_paths.h
  index 0c108eea..a766f563 100644
  --- a/runner/src/host_paths.h
  +++ b/runner/src/host_paths.h
  @@ -21,6 +21,15 @@ int snesrecomp_abspath(const char *path, char *out, size_t max_len);
    */
   int snesrecomp_exe_dir_path(const char *leaf, char *out, size_t max_len);
   
  +/*
  + * Build an absolute path for `leaf` in the directory this run may write to.
  + * Same as snesrecomp_exe_dir_path() everywhere except inside a macOS .app
  + * bundle, where it is ~/Library/Application Support/<bundle name>/ instead: a
  + * bundle is sealed and often read-only, so config.ini, keybinds.ini, rom.cfg
  + * and saves must not live inside it. Falls back to the executable directory.
  + */
  +int snesrecomp_state_dir_path(const char *leaf, char *out, size_t max_len);
  +
   /*
    * Full path of the running executable -- inside an AppImage, the .AppImage
    * file itself, which is what a relaunch must start. Returns 0 when the
  diff --git a/runner/src/keybinds.c b/runner/src/keybinds.c
  index 7844388d..3e2cb757 100644
  --- a/runner/src/keybinds.c
  +++ b/runner/src/keybinds.c
  @@ -1,11 +1,15 @@
   /*
    * keybinds.c — SNES controller keybinds, INI-driven.
    *
  - * INI lives next to the exe as keybinds.ini. Auto-generated with sane
  - * defaults when missing. Edit and restart to apply.
  + * INI is the keybinds.ini of the run's writable state directory (next to the
  + * exe outside a macOS bundle, in ~/Library/Application Support/<bundle name>/
  + * inside one; see host_paths.c). Auto-generated with sane defaults when
  + * missing. Edit and restart to apply.
    */
   #include "keybinds.h"
   
  +#include "host_paths.h"
  +
   #include <stdio.h>
   #include <string.h>
   #include <stdlib.h>
  @@ -150,6 +154,17 @@ static void derive_ini_path(const char *exe_path) {
       const char *appimage = getenv("APPIMAGE");
       if (appimage && *appimage) exe_path = appimage;
   #endif
  +    /* keybinds.ini is written on the first run when it is missing and again
  +     * whenever a binding changes, so it is written state. Inside a macOS bundle
  +     * that means the state directory: a keybinds.ini beside the executable
  +     * would invalidate the bundle's code seal the first time it is written.
  +     * Outside a bundle the two lookups name the same file, so the argv[0]-based
  +     * path below is kept and development layouts keep finding what they use. */
  +    char exe_leaf[512];
  +    if (snesrecomp_state_dir_path("keybinds.ini", s_ini_path, sizeof(s_ini_path)) &&
  +        snesrecomp_exe_dir_path("keybinds.ini", exe_leaf, sizeof(exe_leaf)) &&
  +        strcmp(s_ini_path, exe_leaf) != 0)
  +        return;
       if (!exe_path || !*exe_path) {
           strcpy(s_ini_path, "keybinds.ini");
           return;
  diff --git a/runner/src/launcher_cache.c b/runner/src/launcher_cache.c
  index b425c72e..428b85e4 100644
  --- a/runner/src/launcher_cache.c
  +++ b/runner/src/launcher_cache.c
  @@ -6,7 +6,10 @@
   #include <string.h>
   
   static void rom_cache_path(char *out, size_t max_len) {
  -    if (!snesrecomp_exe_dir_path("rom.cfg", out, max_len))
  +    /* The cached choice is written state, so it goes to the writable state
  +     * directory rather than next to the executable: inside a macOS bundle that
  +     * means outside the .app. */
  +    if (!snesrecomp_state_dir_path("rom.cfg", out, max_len))
           snprintf(out, max_len, "rom.cfg");
   }
   

== 2. the host-side symbols each capability needs, counted per checkout ==

  absent at the pin and present at the branch head is what makes a capability a
  framework change rather than something this port already had.  Counts are
  lines matching in the file named, per checkout, from the same clones as section 0.
  Not every symbol listed is new: what matters is the 0 at the pin.  A nonzero
  count there would mean the hook already existed and the commit only reached for it,
  which is a different claim, so the table shows both kinds rather than a curated one.

  file: runner/src/desktop/host_main.c
      g_rom_embedded                pin=0  shareable=0  personal=6
      HostEmbeddedRomReady          pin=0  shareable=0  personal=3
      snesrecomp_embedded_rom       pin=0  shareable=0  personal=5
      embedded:                     pin=0  shareable=0  personal=1
      Application Support           pin=0  shareable=0  personal=0
      snesrecomp_state_dir_path     pin=0  shareable=1  personal=1
      snesrecomp_anchor_to_exe_dir  pin=2  shareable=2  personal=2

  file: runner/src/host_paths.c
      g_rom_embedded                pin=0  shareable=0  personal=0
      HostEmbeddedRomReady          pin=0  shareable=0  personal=0
      snesrecomp_embedded_rom       pin=0  shareable=0  personal=0
      embedded:                     pin=0  shareable=0  personal=0
      Application Support           pin=0  shareable=3  personal=3
      snesrecomp_state_dir_path     pin=0  shareable=1  personal=1
      snesrecomp_anchor_to_exe_dir  pin=1  shareable=1  personal=1

  the comment in the personal checkout that says the embedded image is re-hashed by
  the same check as a file ROM, quoted with its line number so the prose can cite it:
    3768:   * embedded bytes hash to. The check is the same one, not a weaker one. */

== 3. shareable framework versus personal framework ==

  both carry the writable-state fix; only one carries the embedded guest.  That is
  what lets the packaging transcripts compare a payload that reads a ROM file with
  one whose guest came out of its own executable and attribute the difference to the
  guest alone.  The diff below is the whole of what separates the two trees.

  commits in personal that are not in shareable:
    a7fb67e6 runner/macos: keep writable state out of the .app bundle
    c5024e74 runner/desktop: boot an embedded guest image (SNESRECOMP_EMBEDDED_ROM)
    76eda6dd docs/validation: record the cycle-charging collision with current upstream (Axis 2)
    8d9f9991 docs/validation: record the AOT/floor frame-phase hand-off ruling (Axis 6)
  the state fix as each branch carries it.  Same subject, different hash, because
  the personal branch has it as a cherry-pick; so the comparison to make is of
  content, and what follows is that comparison in both directions -- the fix's own
  files across the two branches, then the whole tree.
    shareable: 32266300 runner/macos: keep writable state out of the .app bundle
    personal:  a7fb67e6 runner/macos: keep writable state out of the .app bundle
  same content check -- diffing the two state-fix commits against each other:
    personal's copy of the state fix: a7fb67e6 runner/macos: keep writable state out of the .app bundle
    the files that fix touches, other than the one the embedded guest also edits,
    diffed across the two branches:
    empty output above means those files are identical on both branches, so the
    two frameworks do carry the same state code.
    host_main.c does differ across those two commits, and that diff is the guest:
     runner/src/desktop/host_main.c | 118 ++++++++++++++++++++++++++++++++++++++---
     1 file changed, 112 insertions(+), 6 deletions(-)
    host_paths.c as each branch has it, hashed rather than eyeballed:
      shareable 406bb22d7c05543a  runner/src/host_paths.c
      shareable 188db8281348b28f  runner/src/keybinds.c
      personal 406bb22d7c05543a  runner/src/host_paths.c
      personal 188db8281348b28f  runner/src/keybinds.c
  the whole of what separates the two trees, with no path limit:
     docs/validation/accuracy-history.md | 113 ++++++++++++++++++++++++++++++++++
     runner/src/desktop/host_main.c      | 118 ++++++++++++++++++++++++++++++++++--
     2 files changed, 225 insertions(+), 6 deletions(-)
  the runner/src part of that diff, which is the only part the payload can contain:
     runner/src/desktop/host_main.c | 118 ++++++++++++++++++++++++++++++++++++++---
     1 file changed, 112 insertions(+), 6 deletions(-)
  so the two frameworks this round built from differ by one host file: the guest.
  That is the witness for the packaging transcripts pairing a payload that reads a
  ROM file with one whose guest came out of its own .text, and for the state fix
  being common to both.

== 4. the SDL3 release each framework checkout pins, and what the floor-11 caches recorded ==

  the packaging round builds SDL3 from source at a macOS 11 floor, so the exact
  SDL3 release matters to the shipped bytes.  A framework that pins a release
  declares it, so the numbers below are grep output from the same checkouts section
  0 named, and the cache lines are grep output from the same build trees section 0
  named.  Two statements of the same digest in two kinds of file is the point: a
  checkout that disagreed with the build would show up here as a mismatch.

  as each framework checkout declares it (runner/runner.cmake, -A1 so the digest
  on the continuation line is shown, line numbers kept):
    pin  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
      92:set(SNESRECOMP_SDL3_FETCH_VERSION "3.4.10" CACHE STRING
      93-    "SDL3 release built when SNESRECOMP_SDL3_FETCH kicks in")
      94:set(SNESRECOMP_SDL3_FETCH_SHA256
      95-    "12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"
    shareable  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
      92:set(SNESRECOMP_SDL3_FETCH_VERSION "3.4.10" CACHE STRING
      93-    "SDL3 release built when SNESRECOMP_SDL3_FETCH kicks in")
      94:set(SNESRECOMP_SDL3_FETCH_SHA256
      95-    "12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"
    personal  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx
      92:set(SNESRECOMP_SDL3_FETCH_VERSION "3.4.10" CACHE STRING
      93-    "SDL3 release built when SNESRECOMP_SDL3_FETCH kicks in")
      94:set(SNESRECOMP_SDL3_FETCH_SHA256
      95-    "12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"

  the same file's mechanism, grep -n, so a claim about where the fetch option is
  declared, where the library is forced static, or where a caller may hand the
  framework a source tree is a line number in this record and not a guess:
    pin  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
      90:option(SNESRECOMP_SDL3_FETCH
      91-    "When no SDL3 package is found, build the pinned SDL3 release from source" ON)
      --
      109:            set(SDL_SHARED OFF CACHE BOOL "" FORCE)
      110:            set(SDL_STATIC ON CACHE BOOL "" FORCE)
      111-            set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
      --
      117:            if(DEFINED SNESRECOMP_SDL3_SOURCE_DIR AND
      118:               EXISTS "${SNESRECOMP_SDL3_SOURCE_DIR}/CMakeLists.txt")
      119-                # A pre-fetched tree (CI caches one; curl --http1.1 is more
      --
      121:                FetchContent_Declare(SDL3 SOURCE_DIR "${SNESRECOMP_SDL3_SOURCE_DIR}")
      122-            else()
      123:                FetchContent_Declare(SDL3
      124-                    URL "${_snesrecomp_sdl3_url}"
      125:                    URL_HASH "SHA256=${SNESRECOMP_SDL3_FETCH_SHA256}"
      126-                    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
    shareable  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
      90:option(SNESRECOMP_SDL3_FETCH
      91-    "When no SDL3 package is found, build the pinned SDL3 release from source" ON)
      --
      109:            set(SDL_SHARED OFF CACHE BOOL "" FORCE)
      110:            set(SDL_STATIC ON CACHE BOOL "" FORCE)
      111-            set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
      --
      117:            if(DEFINED SNESRECOMP_SDL3_SOURCE_DIR AND
      118:               EXISTS "${SNESRECOMP_SDL3_SOURCE_DIR}/CMakeLists.txt")
      119-                # A pre-fetched tree (CI caches one; curl --http1.1 is more
      --
      121:                FetchContent_Declare(SDL3 SOURCE_DIR "${SNESRECOMP_SDL3_SOURCE_DIR}")
      122-            else()
      123:                FetchContent_Declare(SDL3
      124-                    URL "${_snesrecomp_sdl3_url}"
      125:                    URL_HASH "SHA256=${SNESRECOMP_SDL3_FETCH_SHA256}"
      126-                    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
    personal  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx
      90:option(SNESRECOMP_SDL3_FETCH
      91-    "When no SDL3 package is found, build the pinned SDL3 release from source" ON)
      --
      109:            set(SDL_SHARED OFF CACHE BOOL "" FORCE)
      110:            set(SDL_STATIC ON CACHE BOOL "" FORCE)
      111-            set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
      --
      117:            if(DEFINED SNESRECOMP_SDL3_SOURCE_DIR AND
      118:               EXISTS "${SNESRECOMP_SDL3_SOURCE_DIR}/CMakeLists.txt")
      119-                # A pre-fetched tree (CI caches one; curl --http1.1 is more
      --
      121:                FetchContent_Declare(SDL3 SOURCE_DIR "${SNESRECOMP_SDL3_SOURCE_DIR}")
      122-            else()
      123:                FetchContent_Declare(SDL3
      124-                    URL "${_snesrecomp_sdl3_url}"
      125:                    URL_HASH "SHA256=${SNESRECOMP_SDL3_FETCH_SHA256}"
      126-                    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

  the framework states the same release in its own CI prefetch script, which is
  what the packaging round's -DFETCHCONTENT_SOURCE_DIR_SDL3 mirrors:
    pin  tools/ci/prefetch_sdl3.sh
      16:VERSION="3.4.10"
      17:SHA256="12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"
      48:URL="https://github.com/libsdl-org/SDL/releases/download/release-${VERSION}/SDL3-${VERSION}.tar.gz"
    shareable  tools/ci/prefetch_sdl3.sh
      16:VERSION="3.4.10"
      17:SHA256="12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"
      48:URL="https://github.com/libsdl-org/SDL/releases/download/release-${VERSION}/SDL3-${VERSION}.tar.gz"
    personal  tools/ci/prefetch_sdl3.sh
      16:VERSION="3.4.10"
      17:SHA256="12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785"
      48:URL="https://github.com/libsdl-org/SDL/releases/download/release-${VERSION}/SDL3-${VERSION}.tar.gz"

  and whether that file moves between the pin and the two shipped clones at all:
  if it does not, the line numbers above are also the line numbers the shipped
  builds were configured from, and tests/README.md may cite them.
    pin  at the pin, so nothing to diff
    shareable  git diff --stat 773285b8210f2254ae87d0a14113980fb36990ad..HEAD -- runner/runner.cmake
        runner/runner.cmake unchanged between the pin and this HEAD
    personal  git diff --stat 773285b8210f2254ae87d0a14113980fb36990ad..HEAD -- runner/runner.cmake
        runner/runner.cmake unchanged between the pin and this HEAD

  as each floor-11 build cache recorded it, plus the source directory that cache
  names and that directory's own project() line:
    build-ship-m11
      SDL3_SOURCE_DIR:STATIC=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
      SNESRECOMP_SDL3_FETCH:BOOL=ON
      SNESRECOMP_SDL3_FETCH_SHA256:STRING=12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785
      SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10/CMakeLists.txt:  project(SDL3 LANGUAGES C VERSION "3.4.10")
    build-embed-ship-m11
      SDL3_SOURCE_DIR:STATIC=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
      SNESRECOMP_SDL3_FETCH:BOOL=ON
      SNESRECOMP_SDL3_FETCH_SHA256:STRING=12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785
      SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10/CMakeLists.txt:  project(SDL3 LANGUAGES C VERSION "3.4.10")

== DONE  (log: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/framework/framework_commits.log)
