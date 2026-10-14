#!/usr/bin/env bash
# Disposable live drive of Claude Code Calm working-ship padding.
set -u
ROOT="/home/lewis/.local/share/firstmate/nm-home/worktrees/f0926df37da5/01M4W1AYNBQ6QFHQ880W7NWVY8"
EVID="/home/lewis/.local/share/firstmate/nm-home/evidence/01M4W1AYNBQ6QFHQ880W7NWVY8"
MOD="$ROOT/.claude/mods/firstmate-calm"
HULL='╲▁▁▁╱'
SAIL='◿│◣'
PROMPT='Run this exact bash command with the Bash tool: sleep 12; printf BOATGAP_TOKEN\\n   Then reply with only BOATGAP_TOKEN.'

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
mkdir -p "$LAB/tmux" "$LAB/project/.claude/skills"
ln -s "$MOD" "$LAB/project/.claude/skills/firstmate-calm"
printf 'on\n' >"$LAB/config/calm"
printf 'alpha\n' >"$LAB/project/notes.txt"
printf '%s\n' "$LAB" >"$EVID/lab-path.txt"

DEBUG="$EVID/claude-debug.log"
PROJECT="$LAB/project"

cleanup() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true
  rm -rf "$LAB" 2>/dev/null || true
}
trap cleanup EXIT

unset_inherited() {
  local name
  while IFS= read -r name; do
    printf -- '-u %s ' "$name"
  done < <(env | grep -E '^(CLAUDECODE|CLAUDE_CODE_[A-Z_]+|CLAUDE_CONFIG_DIR|NO_MISTAKES_GATE|FM_GATE_REFUSE_BYPASS|FM_ROOT_OVERRIDE|FM_STATE_OVERRIDE|FM_DATA_OVERRIDE|FM_CONFIG_OVERRIDE|FM_PROJECTS_OVERRIDE)=' | cut -d= -f1 | sort -u)
}

TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab -f /dev/null new-session -d -s primary -x 160 -y 44 -c "$PROJECT" \
  "env $(unset_inherited) -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 FM_HOME='$LAB' CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false CLAUDE_CODE_SEND_FEEDBACK=0 DISABLE_AUTOUPDATER=1 \
    claude --model haiku --dangerously-skip-permissions --settings '{\"feedbackDrafts\":\"off\"}' --debug-file '$DEBUG'; printf '\nCLAUDE_EXIT=%s\n' \"\$?\"; sleep 20"

TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab set-option -t primary status off 2>/dev/null || true

screen() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -p -t primary 2>/dev/null || true
}
screen_esc() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab capture-pane -ep -t primary 2>/dev/null || true
}
send() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary -l "$1"
}
enter() {
  TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary Enter
}

dialog_open() {
  case "$1" in
    *'trust this folder'*|*'Enter to confirm'*) return 0 ;;
  esac
  return 1
}
answer_trust_dialog() {
  local selected
  case "$1" in
    *'Yes, I trust this folder'*) : ;;
    *) return 0 ;;
  esac
  selected=$(printf '%s\n' "$1" | grep -F '❯' | head -1)
  case "$selected" in
    *'Yes, I trust this folder'*) enter ;;
    *) TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary Down ;;
  esac
}

wait_screen() {
  local text=$1 what=$2 limit=${3:-400} i=0 shot
  while [ "$i" -lt "$limit" ]; do
    shot=$(screen)
    case "$shot" in
      *'CLAUDE_EXIT='*)
        printf '%s\n' "$shot" >"$EVID/failed-screen.txt"
        echo "FAIL: Claude exited while waiting for $what" >&2
        return 1
        ;;
    esac
    if dialog_open "$shot"; then
      answer_trust_dialog "$shot"
    else
      case "$shot" in
        *"$text"*) return 0 ;;
      esac
    fi
    sleep 0.25
    i=$((i + 1))
  done
  printf '%s\n' "$(screen)" >"$EVID/failed-screen.txt"
  echo "FAIL: never showed $what" >&2
  return 1
}

wait_idle() {
  wait_screen '❯' 'the composer prompt' || return 1
  sleep 1
  if dialog_open "$(screen)"; then
    wait_screen '❯' 'the composer prompt after the startup dialog' || return 1
  fi
}

echo "waiting for idle..."
wait_idle || exit 1
screen >"$EVID/idle-screen.txt"
screen_esc >"$EVID/idle-screen.ansi"

# Confirm /calm is listed (hooks actually loaded)
send "/calm"
listed=0
i=0
while [ "$i" -lt 40 ]; do
  shot=$(screen)
  case "$shot" in
    *"Toggle Firstmate's Calm"*) listed=1; break ;;
  esac
  sleep 0.1
  i=$((i + 1))
done
TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary C-u
sleep 0.3
echo "calm_listed=$listed" >"$EVID/calm-listed.txt"
if [ "$listed" -ne 1 ]; then
  screen >"$EVID/failed-screen.txt"
  echo "FAIL: /calm not listed" >&2
  exit 1
fi

send "$PROMPT"
enter

echo "waiting for hull..."
wait_screen "$HULL" 'the working ship' 200 || exit 1

# Sample several frames while the boat is up.
n=0
while [ "$n" -lt 8 ]; do
  screen >"$EVID/boat-frame-$n.txt"
  screen_esc >"$EVID/boat-frame-$n.ansi"
  n=$((n + 1))
  sleep 0.4
done

python3 - "$EVID" "$HULL" "$SAIL" <<'PY'
import pathlib, sys, re
evid = pathlib.Path(sys.argv[1])
hull, sail = sys.argv[2], sys.argv[3]
frames = sorted(evid.glob("boat-frame-*.txt"))
ok = 0
reports = []
for path in frames:
    if path.suffix != ".txt":
        continue
    if path.name.endswith(".ansi"):
        continue
    lines = path.read_text(errors="replace").splitlines()
    sail_i = next((i for i,l in enumerate(lines) if sail in l), None)
    hull_i = next((i for i,l in enumerate(lines) if hull in l), None)
    note = [f"== {path.name} =="]
    if sail_i is None or hull_i is None:
        note.append(f"missing sprite sail={sail_i} hull={hull_i}")
        reports.append("\n".join(note))
        continue
    above = lines[sail_i-1] if sail_i else ""
    above2 = lines[sail_i-2] if sail_i >= 2 else ""
    blank = above.strip() == ""
    hull_below = hull_i == sail_i + 1
    note.append(f"sail_line={sail_i} hull_line={hull_i} blank_above_sail={blank} hull_immediately_below={hull_below}")
    ctx_start = max(0, sail_i-5)
    ctx_end = min(len(lines), hull_i+3)
    for i in range(ctx_start, ctx_end):
        mark = ""
        if i == sail_i-1: mark = "  <-- padding row"
        if i == sail_i: mark = "  <-- sail"
        if i == hull_i: mark = "  <-- hull"
        note.append(f"{i:03d}|{lines[i]}{mark}")
    if blank and hull_below:
        ok += 1
    reports.append("\n".join(note))
(evid / "gap-analysis.txt").write_text("\n\n".join(reports) + f"\n\nok_frames={ok}/{len(frames)}\n")
print(f"ok_frames={ok}/{len(frames)}")
sys.exit(0 if ok else 1)
PY
gap_status=$?

# Render HTML evidence from the first good frame (or frame 0).
python3 - "$EVID" <<'PY'
from pathlib import Path
import html, glob
evid = Path(sys.argv[1] if False else "")
PY
python3 - "$EVID" <<'PY'
from pathlib import Path
import html, sys
evid = Path(sys.argv[1])
frame = evid / "boat-frame-0.txt"
text = frame.read_text(errors="replace") if frame.exists() else "missing"
escaped = html.escape(text)
html_doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Calm working boat gap</title>
<style>
body {{ background:#0d1117; color:#e6edf3; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; margin:24px; }}
h1 {{ font-size:16px; font-weight:600; }}
pre {{ background:#161b22; border:1px solid #30363d; border-radius:8px; padding:16px; line-height:1.35; white-space:pre; overflow:auto; }}
.note {{ color:#8b949e; margin-bottom:12px; }}
</style></head><body>
<h1>Claude Code Calm working sailboat — live pane</h1>
<p class="note">One blank row should sit between the highlighted user prompt and the sail (paddingTop 1). Hull on the next row.</p>
<pre>{escaped}</pre>
</body></html>
"""
(evid / "boat-gap.html").write_text(html_doc)
print("wrote html")
PY

# Wait a moment more, then exit Claude if still up.
TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab send-keys -t primary C-c 2>/dev/null || true
sleep 0.5
send "/exit"
enter
sleep 1
echo "gap_status=$gap_status" >>"$EVID/calm-listed.txt"
exit "$gap_status"
