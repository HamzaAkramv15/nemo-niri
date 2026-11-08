#!/bin/sh
# yami-niri session with a safety net (ExecStart of niri.service through the yami-niri drop-in).
# The fork starts unless it is missing or rejects the config; if it dies within 15 s of starting,
# the packaged niri takes over, so a broken build never locks you out. Logs: journalctl --user -u niri
FORK="$HOME/.local/lib/yami-niri/current/niri"
fallback() {
    # the packaged niri does not know the fork's window rules: drop them from the yami shell's rules
    # (it rewrites the file; ~/.config/yami/niri/rules.kdl, before yami 3.0 niri/yami-fx.kdl)
    c="${XDG_CONFIG_HOME:-$HOME/.config}"
    for fx in "$c/yami/niri/rules.kdl" "$c/niri/yami-fx.kdl"; do
        [ -f "$fx" ] && sed -i '/allow-tearing/d; /show-only-in/d; s/hide-from /block-out-from /' "$fx"
    done
    for n in /usr/bin/niri /usr/local/bin/niri; do
        [ -x "$n" ] && { echo "yami-niri: $1, starting $n" >&2; exec "$n" --session; }
    done
    echo "yami-niri: $1 and no packaged niri" >&2
    exit 1
}
[ -x "$FORK" ] || fallback "no build"
"$FORK" validate >/dev/null 2>&1 || fallback "the config fails validation"
start=$(date +%s)
"$FORK" --session
rc=$?
[ "$rc" -eq 0 ] && exit 0
[ $(($(date +%s) - start)) -lt 15 ] && fallback "exited with $rc right after the start"
exit "$rc"
