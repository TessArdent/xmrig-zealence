# XMRig 6.26.0 as shipped with Zealence

This is the source of the `xmrig.exe` that the Zealence installer puts in
`plugins\xmrig`. It is [XMRig](https://github.com/xmrig/xmrig) 6.26.0 by the
XMRig developers, licensed under the GNU General Public License v3 (see
[LICENSE](LICENSE)), with one change.

## Modification

Modified by Tess Ardent on 28 September 2026:

- `src/donate.h`: `kDefaultDonateLevel` and `kMinimumDonateLevel` changed
  from 1 to 0, so the developer donation can be set to 0%. Zealence leaves the
  choice to the user (Mining > Miners > XMRig > Developer donation).

Nothing else differs from the `v6.26.0` tag. Compare:
<https://github.com/TessArdent/xmrig-zealence/compare/v6.26.0...zealence-6.26.0>

If you use the 0% setting, please consider supporting the XMRig developers
directly (see the note in `src/donate.h`).

## Building

`scripts/build-zealence.ps1` is the script used to build the shipped binary:
Windows, Visual Studio 2022 or newer with the C++ desktop tools, CMake and
Ninja, Release build with CMake's defaults.

Dependencies (libuv, hwloc, OpenSSL) are XMRig's own prebuilt Windows static
libraries from <https://github.com/xmrig/xmrig-deps>, commit `ddfb65e`,
folder `msvc2022/x64`. Their sources and licences are listed in that
repository.
