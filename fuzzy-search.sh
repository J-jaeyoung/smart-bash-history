# interactive, fuzzy history search (requires https://github.com/junegunn/fzf)
if which fzf >/dev/null; then
  __history_fzf_search() (
    __reload_history
    # read directly from history files to show directory annotations
    cat $(
      ls $HISTFILE 2>/dev/null
      ls ${HISTFILE}.* 2>/dev/null | grep "\.[0-9]*$"
    ) | grep -av '^#[0-9]*$' |
      fzf --height 50% --tiebreak=index --bind=ctrl-r:toggle-sort \
      --tac --sync --no-multi "--query=$*" |
      sed 's/    # \/.*$//' ||
      # restore typed input if fzf aborted
      echo $*
  )
  # replace default Ctrl-R mapping
  bind '"\er": redraw-current-line'  # helper
  bind '"\C-r": " \C-e\C-u`__history_fzf_search \C-y`\e\C-e\er"'
fi

