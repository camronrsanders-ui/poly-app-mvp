# Polycircle branding source of truth

## Approved master logo

The approved Polycircle logo is the dark-purple square artwork selected by the product owner from the earlier generated asset:

- source filename: `a_logo_for_an_app_named_polycircle_is_displayed.png`
- canvas: 1024 x 1024
- color mode: RGB
- SHA-256 of the approved source image: `45ad99e923294cea8d33457c2f4200e82affa10efa5c011cdd691f0bdd392f20`

Do not silently replace this artwork with the light/lavender alternative, a generic Flutter icon, or a newly generated interpretation.

## Native launcher icons

The iOS and Android launcher icons are derived artifacts. They must be generated from the approved master logo above and visually checked at small launcher sizes. A correct logo shown inside Flutter does not prove the native launcher assets are correct.

Because repository automation currently edits UTF-8 source files but does not safely upload arbitrary binary assets, the approved binary master is tracked by filename + SHA-256 here until it is installed into the native asset catalogs from the exact selected PNG. Do not fabricate or substitute an image simply to close the branding gate.

## Platform requirements

- iOS: install the derived PNG sizes into `Runner/Assets.xcassets/AppIcon.appiconset` and keep the asset catalog metadata consistent with the generated files.
- Android: install derived launcher resources for the supported mipmap densities, and review adaptive-icon foreground/background behavior where applicable.
- Splash/launch branding is a separate review from launcher icon branding.

## Verification

A branded build is not considered verified until:

1. the source master hash matches the value above;
2. iOS launcher icon is visibly correct in the simulator/device launcher;
3. Android launcher icon is visibly correct on an emulator/device;
4. no default Flutter placeholder icon remains;
5. launch/splash branding uses approved Polycircle artwork or an explicitly approved simplified variant.
