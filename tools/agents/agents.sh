#!/bin/bash
# Agent jobs: status of every worktree, and restart of background jobs killed by a shutdown.
#   tools/agents/agents.sh status            read-only overview
#   tools/agents/agents.sh restart lore      restart the lore autoloop (resumable)
#   tools/agents/agents.sh codex <worktree> <brief.md> [model]
#                                            launch Codex on a worktree with a brief (detached)
# Logs go to $WT/_agent/<job>.log. Launched jobs survive the session (setsid nohup).
set -u
REPO=/home/diego/Desarrollo/cpore
WT=/home/diego/Desarrollo/cpore-wt
LOG=$WT/_agent
MAIN=claude/v0.1-restore

status() {
  printf '%-28s %-34s %6s %6s  %s\n' WORKTREE BRANCH AHEAD DIRTY LAST
  git -C "$REPO" worktree list --porcelain | awk '/^worktree /{w=$2} /^branch /{sub("refs/heads/","",$2); print w, $2}' |
  while read -r w b; do
    [ "$w" = "$REPO" ] && continue
    ahead=$(git -C "$w" rev-list --count "$MAIN..HEAD" 2>/dev/null || echo ?)
    dirty=$(git -C "$w" status --porcelain 2>/dev/null | wc -l)
    [ "$ahead" = 0 ] && [ "$dirty" = 0 ] && continue  # nothing unmerged and clean: skip
    last=$(git -C "$w" log -1 --format='%cr %s' 2>/dev/null | cut -c1-50)
    printf '%-28s %-34s %6s %6s  %s\n' "$(basename "$w")" "$b" "$ahead" "$dirty" "$last"
  done
  echo
  echo "Running agent processes (mine):"
  ps -u "$(id -u)" -o pid=,etime=,args= | grep -E 'codex exec|opencode run|agent -p |autoloop.py' | grep -v grep || echo "  none"
}

restart_lore() {
  cd "$WT/lore-autoloop2" || exit 1
  setsid nohup nice -n 10 python3 tools/lore/council/autoloop.py --include-paused --no-wait-opus \
    >> "$LOG/lore-autoloop2.log" 2>&1 < /dev/null &
  echo "lore autoloop pid $!"
}

codex_job() {
  local w=$1 brief=$2 model=${3:-gpt-6.1-sol}
  cd "$WT/$w" || exit 1
  setsid nohup codex exec -m "$model" -s workspace-write --add-dir "$REPO/.git" "$(cat "$brief")" \
    > "$LOG/codex-$w.log" 2>&1 < /dev/null &
  echo "codex $model on $w pid $!"
}

case "${1:-status}" in
  status) status ;;
  restart) case "${2:-}" in lore) restart_lore ;; *) echo "unknown job: ${2:-}"; exit 1 ;; esac ;;
  codex) codex_job "$2" "$3" "${4:-}" ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
