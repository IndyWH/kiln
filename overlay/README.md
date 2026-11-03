# Kiln recipes

Kiln's own Gentoo recipes, for what Gentoo's main repo does not have. Licence GPL-2, written for Kiln from each project's own build files. Sources come straight from each project.

Hyprland 0.57 and the libraries it needs. To update, read the new version's `CMakeLists.txt`, add a new recipe, and run `ebuild <file> manifest`.

`dev-lang/lua` 5.5 is here because Gentoo stops at 5.4, and Hyprland 0.57 needs 5.5. It only installs a library for Hyprland to build against. Drop it when Gentoo adds 5.5.
