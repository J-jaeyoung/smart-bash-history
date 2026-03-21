# Capture PWD before each command via DEBUG trap (so `cd` doesn't affect it)
__sbh_capture_pwd() {
    __sbh_cmd_pwd="$PWD"
}
trap '__sbh_capture_pwd' DEBUG

# Annotate last entry in session history file with working directory
__sbh_annotate_last_entry() {
    local session_file="$1"
    local dir="${__sbh_cmd_pwd:-$PWD}"
    [ ! -f "$session_file" ] && return

    local last_line
    last_line=$(tail -1 "$session_file")

    # skip if already annotated or if it's a timestamp line
    [[ "$last_line" == *"    # /"* ]] && return
    [[ "$last_line" =~ ^#[0-9]+$ ]] && return

    sed -i '$ s|$|    # '"$dir"'|' "$session_file"
}
