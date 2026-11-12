# macos_deployment_floor.md
#
# what: which macOS each payload in this port can run on, read out of the
#       Mach-O build records: the port's own target, the SDL3 that travels
#       with it, and the floor each shipped bundle and image claims
# how:  tests/macos_floor_probe.sh with TREES="build-ship build-embed-ship build-osx11 build-osx11-sdl11 build-osx-static build-osx-universal build-fork-osx build-ship-m11 build-embed-ship-m11 build-osx-universal-m11"
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-10T06:24:52Z (host Darwin 25.6.0 arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

  the machine reading this is 26.7.1 (25G241),
  arm64, SDK 26.5 -- every floor below is a claim
  about other machines, which is why it is read off the bytes and not asserted.

== 1. the build trees, in the order the compatibility round tried them ==

  dyld loads the executable plus every non-system dylib it names, so the floor of a
  bundle built from one of these trees is the highest minimum-system version among
  all of those files, and the last line under each tree names the file that supplies
  that number.  A load name that is not absolute (@rpath/...) is resolved at run time
  against the LC_RPATH entries printed under it, i.e. against a dylib the bundle
  carries itself; its build record is read here from the copy the link step used.
  Where two files carry the same number the executable is named.

  build-ship
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:STRING=
    SDL3_DIR:PATH=/opt/homebrew/lib/cmake/SDL3
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad (dirty 0)
    executable                 a0587ed0a0e34687  3103776 B
    architectures              arm64
        thin minos 26.0 sdk 26.5
      non-system dylibs named by the Mach-O: 1
      LC_RPATH entries: 1
        LC_RPATH /opt/homebrew/lib
      /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib                 599c1a000f96797e  minos 26.0
      floor a bundle from this tree needs: macOS 26.0   (highest record: build-ship/ShadowrunSNESRecomp (the executable itself))

  build-embed-ship
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:STRING=
    SDL3_DIR:PATH=/opt/homebrew/lib/cmake/SDL3
    SHADOWRUN_EMBED_ROM:BOOL=ON
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: OFF THE PIN at c5024e74abef0d6b85913baffe8de124c5c7c299 (dirty 0), the pin plus
        3 commit(s)
    executable                 5822a85675b2640d  4160576 B
    architectures              arm64
        thin minos 26.0 sdk 26.5
      non-system dylibs named by the Mach-O: 1
      LC_RPATH entries: 1
        LC_RPATH /opt/homebrew/lib
      /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib                 599c1a000f96797e  minos 26.0
      floor a bundle from this tree needs: macOS 26.0   (highest record: build-embed-ship/ShadowrunSNESRecomp (the executable itself))

  build-osx11
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    SDL3_DIR:PATH=/opt/homebrew/lib/cmake/SDL3
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad (dirty 0)
    executable                 ec482cf36614c938  3111536 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 1
      LC_RPATH entries: 1
        LC_RPATH /opt/homebrew/lib
      /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib                 599c1a000f96797e  minos 26.0
      floor a bundle from this tree needs: macOS 26.0   (highest record: /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib)

  build-osx11-sdl11
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    SDL3_DIR:UNINITIALIZED=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-11/lib/cmake/SDL3
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad (dirty 0)
    executable                 c743eb8a0d417d55  3111536 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 1
      LC_RPATH entries: 1
        LC_RPATH /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-11/lib
      @rpath/libSDL3.0.dylib                                     190c82eeeddca0db  minos 11.0  (read from its LC_RPATH copy)
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-osx11-sdl11/ShadowrunSNESRecomp (the executable itself))

  build-osx-static
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-src
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad (dirty 0)
    executable                 bdf5117aa9fff69c  5969936 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 0
      LC_RPATH entries: 0
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-osx-static/ShadowrunSNESRecomp (the executable itself))

  build-osx-universal
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    SDL3_DIR:UNINITIALIZED=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-11/lib/cmake/SDL3
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad (dirty 0)
    executable                 9b003463ad4d51df  6126192 B
    architectures              x86_64 arm64
         x86_64 minos 11.0 sdk 26.5
         arm64 minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 1
        (2 load command lines: a fat file repeats every one of them per slice)
      LC_RPATH entries: 1
        LC_RPATH /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-11/lib
      @rpath/libSDL3.0.dylib                                     190c82eeeddca0db  minos 11.0  (read from its LC_RPATH copy)
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-osx-universal/ShadowrunSNESRecomp (the executable itself))

  build-fork-osx
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-src
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: OFF THE PIN at 32266300d722b8b31cde3bbdc55614587f7653ae (dirty 0), the pin plus
        1 commit(s)
    executable                 092b0e690cab97a1  5970048 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 0
      LC_RPATH entries: 0
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-fork-osx/ShadowrunSNESRecomp (the executable itself))

  build-ship-m11
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: OFF THE PIN at 32266300d722b8b31cde3bbdc55614587f7653ae (dirty 0), the pin plus
        1 commit(s)
    executable                 092b0e690cab97a1  5970048 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 0
      LC_RPATH entries: 0
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-ship-m11/ShadowrunSNESRecomp (the executable itself))

  build-embed-ship-m11
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    SHADOWRUN_EMBED_ROM:BOOL=ON
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: OFF THE PIN at a7fb67e6c9f5644a98ade281b6d157693a31eb52 (dirty 0), the pin plus
        4 commit(s)
    executable                 594499e83171a0f8  7026848 B
    architectures              arm64
        thin minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 0
      LC_RPATH entries: 0
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-embed-ship-m11/ShadowrunSNESRecomp (the executable itself))

  build-osx-universal-m11
    CMAKE_BUILD_TYPE:STRING=Release
    CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON
    CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0
    FETCHCONTENT_SOURCE_DIR_SDL3:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
    SNESRECOMP_SDL3_FETCH:BOOL=ON
    SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10
      framework: OFF THE PIN at 32266300d722b8b31cde3bbdc55614587f7653ae (dirty 0), the pin plus
        1 commit(s)
    executable                 47ef23a1de7eab93  12146816 B
    architectures              x86_64 arm64
         x86_64 minos 11.0 sdk 26.5
         arm64 minos 11.0 sdk 26.5
      non-system dylibs named by the Mach-O: 0
      LC_RPATH entries: 0
      floor a bundle from this tree needs: macOS 11.0   (highest record: build-osx-universal-m11/ShadowrunSNESRecomp (the executable itself))

== 2. the SDL3 a bundle would carry, and what it costs ==

  a vendored dylib is part of the payload, so its build record joins the
  executable's own.  These are the two SDL3 builds this round used:
  libSDL3.0.dylib                                                599c1a000f96797e  2520544 B
    arch arm64
      thin minos 26.0 sdk 26.5
      -> a bundle vendoring this dylib cannot run below macOS 26.0
  libSDL3.0.dylib                                                190c82eeeddca0db  5999648 B
    arch x86_64 arm64
       x86_64 minos 11.0 sdk 26.5
       arm64 minos 11.0 sdk 26.5
      -> a bundle vendoring this dylib cannot run below macOS 11.0
  the static shape has no dylib to carry: SDL3 becomes part of the executable at
  link time, so the only build record in the bundle is the executable's, and the
  deployment target given to the port is then the whole of the floor.  That is the
  difference sections 1 and 3 measure between the shipped package and the earlier
  one; the same SDL3 sources, built from the version the framework pins for CI
  (tools/ci/prefetch_sdl3.sh), are behind both.

== 3. what is actually shipped ==

  dist/Shadowrun.app
    Contents/MacOS/Shadowrun                 37d08a86a2a86414  5953488 B
      arch arm64
          thin minos 11.0 sdk 26.5
      Mach-O files in the bundle: 1
      bundle claims it needs macOS: 11.0
      floor from its Mach-Os:      11.0
  dist/Shadowrun-personal.app
    Contents/MacOS/Shadowrun-personal        44a3da74ddca0062  7004144 B
      arch arm64
          thin minos 11.0 sdk 26.5
      Mach-O files in the bundle: 1
      bundle claims it needs macOS: 11.0
      floor from its Mach-Os:      11.0
  shadowrun-0.1.0-macos-arm64.dmg                      fe2648738fad58a6  2221175 B
      hdiutil: verify: checksum of "dist/shadowrun-0.1.0-macos-arm64.dmg" is VALID
  shadowrun-embed-0.1.0-macos-arm64-personal.dmg       7edb5fe11827d880  2949133 B
      hdiutil: verify: checksum of "dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg" is VALID
  a .dmg hash pins a run, not a build: hdiutil stamps volume dates and UUIDs into
  the container, and section 4 of each package transcript measures that directly.
  What the README inside each image says a person needs is written by
  scripts/package_macos_bundle.sh from the executable's own LC_BUILD_VERSION, so
  the number in the image and the number in the payload cannot drift apart.

== 4. the compile evidence for a floor older than this machine ==

  Shipping a floor of 11.0 from an SDK this new is only safe if no guarded API is
  reached unconditionally; clang says so with -Wunguarded-availability, and the
  build logs below are counted rather than trusted:
  The last of them, tests/out/m11_check_build.log, comes from
  tests/macos_floor11_check.sh: a tree configured and built in a directory that
  did not exist when that script started, so its counts are not inherited from
  objects already compiled in a tree someone left behind.
  tests/out/osx11_build.log: warning lines 4, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 0
    every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: building for macOS-11.0, but linking with dylib '/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib' which was built for newer version 26.0
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/osx11_sdl11_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 0
    every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/osx_universal_build.log: warning lines 5, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 0
    every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
      ld: warning: ignoring duplicate libraries: '-lm'
  tests/out/osx_static_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 1
    every 'error' substring in this log is a compile line for an SDL source file
    named SDL_error.c; the 'error: ' count above is what a compiler diagnostic
    would produce, which is why the two are reported separately rather than one
    grep being trusted.  Every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/fork_osx_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 1
    every 'error' substring in this log is a compile line for an SDL source file
    named SDL_error.c; the 'error: ' count above is what a compiler diagnostic
    would produce, which is why the two are reported separately rather than one
    grep being trusted.  Every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/ship_m11_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 1
    every 'error' substring in this log is a compile line for an SDL source file
    named SDL_error.c; the 'error: ' count above is what a compiler diagnostic
    would produce, which is why the two are reported separately rather than one
    grep being trusted.  Every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/embed_m11_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 1
    every 'error' substring in this log is a compile line for an SDL source file
    named SDL_error.c; the 'error: ' count above is what a compiler diagnostic
    would produce, which is why the two are reported separately rather than one
    grep being trusted.  Every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  tests/out/m11_check_build.log: warning lines 3, -Wunguarded-availability 0, error: lines 0,
    lines containing the string 'error' 1
    every 'error' substring in this log is a compile line for an SDL source file
    named SDL_error.c; the 'error: ' count above is what a compiler diagnostic
    would produce, which is why the two are reported separately rather than one
    grep being trusted.  Every warning line this log has is printed under this:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx/runner/src/desktop/opengl.h:25:65: warning: '/*' within block comment [-Wcomment]
      ld: warning: ignoring duplicate libraries: '-lm'
      ld: warning: reducing alignment of section __DATA,__common from 0x8000 to 0x4000 because it exceeds segment maximum alignment
  and the one log that records the configure command lines as well as the compile,
    tests/out/m11_build.log.  It holds three builds back to back, so its counts are
    taken per block rather than per file, and each block's command line is printed
    with its counts instead of being left in a shell history somewhere:
  build-ship-m11: warning lines 3, -Wunguarded-availability 0, error: lines 0
      cmake -S . -B build-ship-m11 -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DFETCHCONTENT_SOURCE_DIR_SDL3=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10 -DSNESRECOMP_ENABLE_MODS=ON 
      payload:  092b0e690cab97a1  5970048 B
  build-embed-ship-m11: warning lines 3, -Wunguarded-availability 0, error: lines 0
      cmake -S . -B build-embed-ship-m11 -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DFETCHCONTENT_SOURCE_DIR_SDL3=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10 -DSNESRECOMP_ENABLE_MODS=ON -DSHADOWRUN_EMBED_ROM=ON
      payload:  594499e83171a0f8  7026848 B
  build-osx-universal-m11: warning lines 5, -Wunguarded-availability 0, error: lines 0
      cmake -S . -B build-osx-universal-m11 -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DFETCHCONTENT_SOURCE_DIR_SDL3=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10 -DSNESRECOMP_ENABLE_MODS=ON -DCMAKE_OSX_ARCHITECTURES=x86_64;arm64
      payload:  47ef23a1de7eab93  12146816 B
  the ld warning inside osx11_build.log is the toolchain itself agreeing with
  section 1: it links objects targeted at macOS-11.0 against libSDL3.0.dylib built
  for 26.0, and that is exactly the mismatch section 1 measures as that tree's floor
  being 26.0 even though its deployment target was set to 11.0.
  A floor is also limited by the libraries a payload asks dyld to find.  Section 1
  counts the non-system ones, and the shipped payload names zero: SDL3 is linked in
  rather than carried.  What it does name is part of macOS, with two exceptions --
  two of the frameworks it names did not exist in the 11.0 release, and both are
  marked weak in the Mach-O.  Weak is dyld's own mechanism for 'this library may be
  absent here': a weak-linked library that cannot be found, and the weak symbols it
  would have provided, resolve to nil instead of failing the load.  So the payload
  asks for two frameworks it can do without on an old system, and section 4 shows
  the compiler raising no -Wunguarded-availability anywhere else.  Which names
  those are, read off the shipped files:
  dist/Shadowrun.app  load names: 23, of which weak: 2
      weak  UniformTypeIdentifiers.framework  UniformTypeIdentifiers (compatibility version 1.0.0, current version 709.0.0, weak)
      weak  CoreHaptics.framework  CoreHaptics (compatibility version 1.0.0, current version 1.0.0, weak)
    (every other load name is under /System/Library/Frameworks or /usr/lib:
     0  outside those two places)
  dist/Shadowrun-personal.app  load names: 23, of which weak: 2
      weak  UniformTypeIdentifiers.framework  UniformTypeIdentifiers (compatibility version 1.0.0, current version 709.0.0, weak)
      weak  CoreHaptics.framework  CoreHaptics (compatibility version 1.0.0, current version 1.0.0, weak)
    (every other load name is under /System/Library/Frameworks or /usr/lib:
     0  outside those two places)

== 5. what this machine can actually execute ==

  Every floor above is a build record, and a build record says what dyld will
  insist on, not that anything ran.  The one claim that cannot be read off bytes is
  whether a machine of the other architecture would run a payload at all, so it is
  measured here rather than assumed:
  this machine: arm64 Darwin 25.6.0, macOS 26.7.1 (25G241)
  hw.optional.arm64: 1
  arch -x86_64 /usr/bin/true: exit 1 arch: posix_spawnp: /usr/bin/true: Bad CPU type in executable
      -> this machine cannot execute x86_64 code at all.  Every x86_64 record above is
         a compile-and-link measurement; nothing in this repository has booted a
         x86_64 image on a x86_64 machine, and arm64-only claims do not depend on it.
  arch -arm64 /usr/bin/true: exit 0 (ran, no output)
      -> this machine can execute arm64 code, so a arm64 payload here would have been
         run-tested in principle
  So: the arm64 floors are what a shipped, arm64-only payload will require, and the
  x86_64 slice measured in section 1 (build-osx-universal) is evidence that a
  deployment target of 11.0 is reachable for that architecture too -- nothing more.
  A floor of 11.0 has not been run on an 11.0 machine either; what section 4 shows is
  that the compiler raised no -Wunguarded-availability for it, which is the check
  that would catch reaching an API newer than the floor, and section 4 also names
  the two frameworks the payload asks for weakly -- the only libraries it asks dyld
  to find that an older system may not have.

== 6. the configure line nobody wrote down, and whether it rebuilds the bytes that shipped ==

  Every build log section 4 counts for the two trees this package ships begins at the
  compile step, so not one of them records a configure command line: the recipe that
  produced the floor-11 trees survived only as entries in each tree's CMakeCache.txt,
  which is a record of what was decided but not of what was typed.  That matters
  because a floor nobody can rebuild is a claim about one machine's afternoon rather
  than a property of the port.  tests/out/m11_build.log is a re-run of those trees
  with the command lines printed as they run; the question is whether it lands on the
  same payload bytes as the earlier round's own summary of the same trees.  Three
  records, read off the files, and a comparison rather than an assurance:
  build-ship-m11:
      earlier record (m11_builds.log): build-ship-m11/ShadowrunSNESRecomp 092b0e690cab97a1 minos 11.0 size 5970048 
      this rebuild  (m11_build.log):    092b0e690cab97a1  5970048 B
      tree on disk  (build-ship-m11): 092b0e690cab97a1  5970048 B
    all three are the same value, so the command lines printed above rebuilt the
    payload the earlier round built: the floor-11 recipe is reproducible, and the
    CMakeCache entries section 1 prints are the ones it had to have used.
  build-embed-ship-m11:
      earlier record (m11_builds.log): build-embed-ship-m11/ShadowrunSNESRecomp 594499e83171a0f8 minos 11.0 size 7026848 
      this rebuild  (m11_build.log):    594499e83171a0f8  7026848 B
      tree on disk  (build-embed-ship-m11): 594499e83171a0f8  7026848 B
    all three are the same value, so the command lines printed above rebuilt the
    payload the earlier round built: the floor-11 recipe is reproducible, and the
    CMakeCache entries section 1 prints are the ones it had to have used.
  build-osx-universal-m11:
        earlier record (m11_builds.log): absent
      this rebuild  (m11_build.log):    47ef23a1de7eab93  12146816 B
      tree on disk  (build-osx-universal-m11): 47ef23a1de7eab93  12146816 B
  A second comparison, inside the tree list itself: build-fork-osx is the
    compatibility round's own build, build-ship-m11 is the one the shipped package is
    built from.  They are separate trees, configured and built apart from each other,
    and their caches name two different SDL3 source directories:
      build-fork-osx       092b0e690cab97a1  5970048 B
        SDL3 source dir  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-src
        it declares       project(SDL3 LANGUAGES C VERSION "3.4.10")
      build-ship-m11       092b0e690cab97a1  5970048 B
        SDL3 source dir  /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/SDL3-3.4.10
        it declares       project(SDL3 LANGUAGES C VERSION "3.4.10")
    cmp finds no differing byte between the two, so two trees built apart from each
    other, from two SDL3 source directories that both declare the same version, come
    out at the same payload.  What decides those bytes is the framework commit and the
    deployment target -- not which checkout of the same SDL3 sat in the build -- and
    that is what makes a payload hash a usable identity for a build in this kit.
  One tree is in that list for a different reason.  build-osx-universal-m11 is the
  same recipe with -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" added, which is the only
  way an Intel slice exists at this floor at all: Homebrew's SDL3 has no x86_64 bottle
  on this machine and its dylib is arm64-only, so a universal payload cannot be built by
  linking against it, and section 2 is where that shows.  Section 5 is where what this
  machine cannot do with that slice is stated.

== DONE ==
