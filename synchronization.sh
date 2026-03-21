# on every prompt, save new history to dedicated file and recreate full history
# by reading all files, always keeping history from current session on top.
__reload_history () {
  history -a ${HISTFILE}.$$
  __sbh_annotate_last_entry "${HISTFILE}.$$"
  history -c
  # load history into memory with annotations stripped (for arrow-key navigation)
  local __tmp_clean=$(mktemp)
  cat $(
    # main file with merged history
    ls $HISTFILE 2>/dev/null
    # histories of other sessions
    ls ${HISTFILE}.* 2>/dev/null | grep "\.[0-9]*$" | grep -v "${HISTFILE}.$$\$";
    # history of current session (should be on top)
    [ -f "${HISTFILE}.$$" ] && echo "${HISTFILE}.$$"
  ) 2>/dev/null | sed 's/    # \/.*$//' >| "$__tmp_clean"
  history -r "$__tmp_clean"
  rm -f "$__tmp_clean"
}
if [[ "$PROMPT_COMMAND" != *__reload_history* ]]; then
  export PROMPT_COMMAND="__reload_history; $PROMPT_COMMAND"
fi

# append provided file to main history
__merge_history_file() {
  [ $# -ne 1 ] && echo "Missing argument" && return 1
  [ -e "$1" ] && file="$1" || return 0
  echo "Flushing $(basename $file)"
  cat "$file" >> "$HISTFILE"
  rm "$file"
}
# deduplicate main history file, keeping last occurrence of each (cmd + dir) pair
__dedup_history() {
  [ ! -f "$HISTFILE" ] && return
  local tmp=$(mktemp)
  # join timestamp+command into single lines, dedup, split back
  LC_ALL=C awk '/^#[0-9]+$/ { ts=$0; next } { print ts " " $0; ts="" }' "$HISTFILE" |
    tac | LC_ALL=C awk '!seen[substr($0, 12)]++' | tac |
    sed 's/^\(#[0-9]*\) /\1\n/' >| "$tmp"
  # safety: only replace if tmp has content (avoid wiping history on pipeline failure)
  if [ -s "$tmp" ]; then
    \mv -f "$tmp" "$HISTFILE"
    # update backup so next shell won't warn about shrinkage
    [ -n "$HISTBACKUP" ] && command cp "$HISTFILE" "$HISTBACKUP"
  else
    rm -f "$tmp"
  fi
}

flush_current_session_history() {
  __merge_history_file "${HISTFILE}.$$"
  __dedup_history
}
# run it automatically on bash exit
trap flush_current_session_history EXIT

# detect leftover files from crashed sessions and merge them back
active_shells=$(pgrep `ps -p $$ -o comm=`)
grep_pattern=$(for pid in $active_shells; do echo -n "-e \.${pid}\$ "; done)
orphaned_files=$(ls $HISTFILE.[0-9]* 2>/dev/null | grep -v $grep_pattern)

if [ -n "$orphaned_files" ]; then
  echo Found orphaned history files.
  for f in $orphaned_files; do
    echo -n "  "; __merge_history_file "$f"
  done; echo "done."
fi

