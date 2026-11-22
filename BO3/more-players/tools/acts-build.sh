# Builds the mod's scripts into mod files with Atian Tools instead of the Mod Tools.
# Not run by itself: build-boiii.sh and test/bot-test.sh read it in with "source".
#
# Atian Tools (acts.zip from github.com/ate47/atian-cod-tools/releases) is a
# Windows program and is run through Proton's wine. It compiles game scripts and
# packs them into a mod file. It can not pack Lua or settings files, which is why
# a build made this way only suits the BOIII client: BOIII reads the Lua from its
# own ui_scripts folder.
#
# The caller sets:
#   PROJECT    this project's folder
#   ACTS_DIR   the folder that holds bin/acts.exe
#   PROTON     a Proton folder (holds files/bin/wine)
#   WORK       a scratch folder, also used for the wine prefix

acts() {
	WINEPREFIX="$WORK/wineprefix" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" \
		"$PROTON/files/bin/wine" "$ACTS_DIR/bin/acts.exe" "$@" 2>&1 | tr -d '\r' | grep -v 'ntsync\|^Atian tools\|hash(es) compressed' || true
}

# Atian Tools reads the same script source as the Mod Tools except for three
# things, which are changed in the copies it gets: forward slashes in #using,
# no #insert, and the stock REGISTER_SYSTEM macro written out.
prep() {
	sed -e '/^#using /s|\\|/|g' -e '/^#insert /d' \
	    -e 's|^REGISTER_SYSTEM( \("[a-z_]*"\), &__init__, undefined )|function autoexec __init__sytem__() { system::register( \1, \&__init__, undefined, undefined ); }|' \
	    "$1" > "$2"
}

# _zm_score.gsc is the game's own source with one check added, and uses more of
# what Atian Tools does not read: macros with arguments, foreach, [] and a dev
# block. Those are rewritten in its copy as well. The added check is untouched.
prep_stock() {
	prep "$1" "$2"
	python3 -I - "$2" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r'IS_TRUE\(\s*([^()]*?)\s*\)', r'( isdefined( \1 ) && \1 )', text)
text = re.sub(r'\bVERSION_SHIP\b', '1', text)
text = re.sub(r'\bMAX_CLIENTS_ZM\b', '4', text)
text = text.replace('= [];', '= array();')
text = re.sub(r'/#.*?#/', '', text, flags=re.S)
text = text.replace(';;', ';')   # a stray empty statement in the stock source
text, loops = re.subn(r'foreach\s*\(\s*(\w+)\s+in\s+([\w.]+)\s*\)(\s*)\{',
                      r'for ( mp_i = 0; mp_i < \2.size; mp_i++ )\3{\3\t\1 = \2[ mp_i ];', text)
left = re.findall(r'\b(?:foreach|IS_TRUE|REGISTER_SYSTEM)\b', text)
assert not left, left
open(path, 'w').write(text)
PY
}

# build_mod <build folder>
# Leaves zm_mod.ff, en_zm_mod.ff, core_mod.ff and en_core_mod.ff in
# <build folder>/output_ff/zone. Prints "BUILD FAILED ..." and returns 1 if not.
build_mod() {
	local B=$1 zone

	[[ -f "$ACTS_DIR/bin/acts.exe" ]] || { echo "No bin/acts.exe in $ACTS_DIR (set ACTS_DIR)." >&2; return 1; }
	[[ -x "$PROTON/files/bin/wine" ]] || { echo "No files/bin/wine in $PROTON (set PROTON)." >&2; return 1; }

	mkdir -p "$B/scripts/zm/gametypes" "$B/scripts/zz_mp_empty" "$WORK/wineprefix"
	rm -f -- "$B/output_ff/zone/zm_mod.ff" "$B/output_ff/zone/en_zm_mod.ff" "$B/output_ff/zone/core_mod.ff" "$B/output_ff/zone/en_core_mod.ff"

	prep "$PROJECT/more_players/scripts/zm/gametypes/_clientids.gsc" "$B/scripts/zm/gametypes/_clientids.gsc"
	prep "$PROJECT/more_players/scripts/zm/_zm_score.csc" "$B/scripts/zm/_zm_score.csc"
	prep "$PROJECT/more_players/scripts/zm/zm_more_players.gsc" "$B/scripts/zm/zm_more_players.gsc"
	prep "$PROJECT/more_players/scripts/zm/zm_more_players.csc" "$B/scripts/zm/zm_more_players.csc"
	prep_stock "$PROJECT/more_players/scripts/zm/_zm_score.gsc" "$B/scripts/zm/_zm_score.gsc" || { echo "BUILD FAILED (_zm_score.gsc rewrite)"; return 1; }

	cat > "$B/zm_mod.zone" <<'ZONE'
>game=bo3
>name=zm_mod
scriptparsetree,scripts/zm/gametypes/_clientids.gsc
scriptparsetree,scripts/zm/zm_more_players.gsc
scriptparsetree,scripts/zm/_zm_score.gsc
scriptparsetree,scripts/zm/_zm_score.csc
scriptparsetree,scripts/zm/zm_more_players.csc
ZONE
	# The game also asks for the language half of the zone and for core_mod. They
	# carry nothing here; the linker wants one asset each, so they get an unused script.
	for zone in en_zm_mod core_mod en_core_mod; do
		printf '#namespace zz_mp_empty_%s;\n\nfunction unused()\n{\n}\n' "$zone" > "$B/scripts/zz_mp_empty/$zone.gsc"
		printf '>game=bo3\n>name=%s\nscriptparsetree,scripts/zz_mp_empty/%s.gsc\n' "$zone" "$zone" > "$B/$zone.zone"
	done

	for zone in zm_mod en_zm_mod core_mod en_core_mod; do
		: > "$B/build.log.$zone"
		( cd "$B" && acts fastfilelinker "$zone.zone" ) > "$B/build.log.$zone"
		if ! grep -q "^Fastfile $zone data linked" "$B/build.log.$zone" || [[ ! -s "$B/output_ff/zone/$zone.ff" ]]; then
			echo "BUILD FAILED ($zone):"; cat "$B/build.log.$zone"; return 1
		fi
	done
	if grep -h 'error\|Error\|Can.t\|not implemented' "$B"/build.log.zm_mod "$B"/build.log.en_zm_mod "$B"/build.log.core_mod "$B"/build.log.en_core_mod; then
		echo "BUILD FAILED"; return 1
	fi

	# The linker stores script names with backslashes and the game looks them up
	# with forward slashes. The file is not compressed, so they are fixed in place.
	python3 -I - "$B/output_ff/zone/zm_mod.ff" <<'PY' || { echo "BUILD FAILED (script names)"; return 1; }
import re, sys
path = sys.argv[1]
data = open(path, 'rb').read()
names = set(re.findall(rb'scripts\\[a-z_\\]+\.(?:gsc|csc)', data))
assert len(names) == 5, names
for name in names:
    data = data.replace(name, name.replace(b'\\', b'/'))
open(path, 'wb').write(data)
PY
	return 0
}
