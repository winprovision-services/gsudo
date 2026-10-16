# WinProvision Elevator

Downstream of gerardog/gsudo v2.6.1 (b7376285a6bb7b180f8a28b42797b0ab5c22dd34), under the original MIT license in LICENSE.txt.

Changes: .NET 10 Native AOT; output WinProvision.Elevator.exe; version 2.6.1.1; isolated registry SOFTWARE\WinProvision\Gsudo, named pipes and cache invalidation events. Removed legacy GitVersion/analyzer packages and the pre-build hook that terminates global gsudo processes. The upstream authentication, client verification and explicit-cache defaults remain in place. No Devolutions code, branding, certificates or signature claims are included.

Build: dotnet publish src/gsudo/gsudo.csproj -c Release -r win-x64 --self-contained true -o artifacts/win-x64

Cache access remains scoped to a consenting process and descendants by the host. This build is unsigned; do not confuse its SHA-256 inventory with Authenticode signing.

Version 2.6.1.2 embeds the WinProvision Store icon and WinProvision Elevator display metadata. The icon is covered by icon/winprovision-LICENSE.txt; the upstream gsudo MIT license remains unchanged.
