== 0. where the inputs come from ==

  baseline tree (the one the shipped .app came from): build-ship-m11
  read out of build-ship-m11/CMakeCache.txt (nothing below is typed by hand):
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    SNESRECOMP_ENABLE_MODS:BOOL=ON
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx

  framework pin this repository records (framework_pins.txt): 773285b8210f2254ae87d0a14113980fb36990ad
  framework /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    HEAD 32266300d722b8b31cde3bbdc55614587f7653ae  dirty 0  commits past the pin: 1
    its last commit: runner/macos: keep writable state out of the .app bundle

  SDL3 source /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    it declares  project(SDL3 LANGUAGES C VERSION "3.4.10")
    version the framework pins for CI: set(SNESRECOMP_SDL3_FETCH_VERSION "3.4.10" CACHE STRING
  the baseline tree's SDL3 source is reused as-is, which is what the floor-11
  round recorded; a different SDL3 checkout would make the comparison in section
  2 a comparison of SDL3 versions rather than of recipes.

  deployment target of the baseline: 11.0   (this script passes it again)

== 1. a clean tree, built from that recipe ==

  rm -rf build-ship-m11-check   (this script never reuses a tree it did not just make)
  cmake -S . -B build-ship-m11-check -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DFETCHCONTENT_SOURCE_DIR_SDL3=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10 -DSNESRECOMP_ENABLE_MODS=ON
  configure exit=0
    configure output, lines:  538
    -- Build files have been written to: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-ship-m11-check
  cmake --build build-ship-m11-check -j 12
  build exit=0
    build output, lines:      901  (with configure's, above)
  what that build produced:
    warning lines:             3
    -W unguarded-availability: 0
    'error:' lines:            0
    every warning line, printed rather than summarised:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
    raw output the counts above were read out of: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/m11_check_build.log
    it holds 901 lines, 60469 B, sha256 6a843387b653a4a3


== 2. the clean tree's payload against the shipped one ==

  shipped tree   092b0e690cab97a1  5970048 B
  clean tree     092b0e690cab97a1  5970048 B
  minimum system version, read off each Mach-O:
    shipped tree:  11.0
    clean tree:    11.0
  dyld asks for (non-system load commands):  shipped 0   clean 0
  architectures:                             shipped 1 slice(s)   clean 1 slice(s)

  the two trees' configuration, key by key, as their own caches record it:
    same     CMAKE_BUILD_TYPE = Release
    same     CMAKE_OSX_DEPLOYMENT_TARGET = 11.0
    same     CMAKE_DISABLE_FIND_PACKAGE_SDL3 = ON
    same     FETCHCONTENT_SOURCE_DIR_SDL3 = /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    same     SNESRECOMP_SDL3_FETCH = ON
    same     SNESRECOMP_SDL3_FETCH_VERSION = 3.4.10
    same     SNESRECOMP_ENABLE_MODS = ON
    same     SNESRECOMP_ROOT = /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    same     SHADOWRUN_EMBED_ROM = OFF
  only the keys this script passes are forced to agree; everything else is left
  at the framework's own default, so a difference here would be the framework's
  default changing underneath the recipe, not this script disagreeing with itself.

  cmp finds no differing byte between build-ship-m11-check/ShadowrunSNESRecomp and build-ship-m11/ShadowrunSNESRecomp
  so the recipe in section 0 reaches the shipped bytes from an empty directory:
  a floor that can only be reached inside a tree someone already built would be
  a claim about one afternoon; this one is a property of the recipe.

  what this does NOT prove, in its own words:
    * it says nothing about whether a macOS 11 machine runs the result; the floor
      is a build record and tests/out/floor/macos_deployment_floor.log §5 is where
      this machine's own reach is measured.
    * the personal variant is not rebuilt here: its payload additionally carries a
      1 MiB generated array, and the framework behind it is a different clone.  Its
      identity is pinned by tests/out/pkg/macos_package_personal.log instead.
    * build-ship-m11-check is a scratch tree, left in place so the byte comparison above can be
      re-run by hand; it is not a shipped artifact and nothing is committed from it.

== DONE (payload bytes match) ==
