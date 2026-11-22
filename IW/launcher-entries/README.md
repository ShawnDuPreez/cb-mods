# Entries for the CB Servers launcher

One folder per mod, in the format of
[CBServers/mods-index](https://github.com/CBServers/mods-index/blob/main/CONTRIBUTING.md):
copy a folder to `items/iw/<id>/` there. Each entry installs one zip from this repository's
release into the game folder. The zip holds `mods/<mod>/...` and, for More Players and Perk
Limit, one host-side menu script under `iw7-mod/ui_scripts/`, so the launcher will show its
"Changes game files" tag for those two. The scripts are new files; they replace nothing.

`size` must match the zip on the release. `tools/make-release-zips.sh` prints the sizes.
Only More Players has an image so far.
