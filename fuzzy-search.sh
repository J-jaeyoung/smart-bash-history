# interactive, fuzzy history search (requires https://github.com/junegunn/fzf)
if which fzf >/dev/null; then
  # source for fzf — current session file LAST so its entries land nearest the
  # prompt (fzf default layout puts cursor just above the prompt, and --tac
  # makes the last input line the cursor's first match).
  # mode: ""/0=all, 1=exact dir, 2=dir + subdirs
  __sbh_fzf_source() {
    local pid="$1" mode="$2" dir="$3"
    cat $(
      ls "$HISTFILE" 2>/dev/null
      ls ${HISTFILE}.* 2>/dev/null | grep "\.[0-9]*$" | grep -v "${HISTFILE}\.${pid}\$"
      [ -f "${HISTFILE}.${pid}" ] && echo "${HISTFILE}.${pid}"
    ) 2>/dev/null | grep -av '^#[0-9]*$' | __sbh_fzf_filter "$mode" "$dir"
  }
  __sbh_fzf_filter() {
    local mode="$1" dir="$2"
    case "$mode" in
      1) awk -v d="    # $dir" 'length($0)>=length(d) && substr($0,length($0)-length(d)+1)==d' ;;
      2) grep -F "    # $dir" ;;
      *) cat ;;
    esac
  }
  # Ctrl-R cycles: 0 (all) → 2 (subdirs) → 1 (exact) → 0
  __sbh_fzf_cycle() {
    local state="$1" m
    m=$(cat "$state" 2>/dev/null)
    if   [ -z "$m" ];    then echo 2 > "$state"
    elif [ "$m" = 2 ];   then echo 1 > "$state"
    else rm -f "$state"
    fi
  }
  __sbh_fzf_reload() {
    local state="$1" pid="$2" dir="$3" m
    m=$(cat "$state" 2>/dev/null)
    __sbh_fzf_source "$pid" "$m" "$dir"
    return 0   # grep returns 1 on no-match — don't let fzf flag "Command failed"
  }
  __sbh_fzf_prompt() {
    local state="$1" dir="$2" m
    m=$(cat "$state" 2>/dev/null)
    case "$m" in
      1) printf '%s > ' "$dir" ;;
      2) printf '%s/** > ' "$dir" ;;
      *) printf '> ' ;;
    esac
  }
  export -f __sbh_fzf_source __sbh_fzf_filter __sbh_fzf_cycle __sbh_fzf_reload __sbh_fzf_prompt

  __history_fzf_search() (
    export HISTFILE   # so fzf's bash -c reload subshells inherit it
    __reload_history
    local cur_dir="$PWD" pid="$$"
    local state="${TMPDIR:-/tmp}/sbh_filter.$$"
    rm -f "$state"
    trap "rm -f '$state'" EXIT

    __sbh_fzf_source "$pid" "" "$cur_dir" |
      fzf --height 50% --tiebreak=index --with-shell="bash -c" \
          --delimiter='    # ' --nth=1 \
          --bind="ctrl-r:execute-silent(__sbh_fzf_cycle '$state')+reload(__sbh_fzf_reload '$state' '$pid' '$cur_dir')+transform-prompt(__sbh_fzf_prompt '$state' '$cur_dir')" \
          --tac --sync --no-multi "--query=$*" |
      sed 's/    # \/.*$//' ||
      # restore typed input if fzf aborted
      echo $*
  )
  # replace default Ctrl-R mapping
  bind '"\er": redraw-current-line'  # helper
  bind '"\C-r": " \C-e\C-u`__history_fzf_search \C-y`\e\C-e\er"'
fi
