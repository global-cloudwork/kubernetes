# ======================== Style Starts Here ========================

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

# ======================== Text Modification Starts Here ========================

# Arguments:
#   $1 - Path to the file to append to
#   $2 - Comma-separated lines to append
append_lines_to_file() {
    [[ -z "$2" ]] && return

    # Append everything before the first comma
    local current=${2%%,*}
    sed -i "$a\\$current" "$1"

    # Pass everything after the first comma
    [[ "$2" == *","* ]] &&
    append_lines_to_file "${2#*,}" "$1"
}

# Arguments:
#   $1 - Path to the file to modify
#   $2 - Regex pattern to search for
#   $3 - Replacement text for the first matching line
replace_first_matching_line() {
    [[ -z "$1" || -z "$2" ]] && return

    # Use sed to replace the first occurrence of a line matching $2 with $3 in $1
    sed -i "s/$2/$3/" "$1"
}

# Arguments:
#   $1 - Path to the file to modify
#   $2 - Regex pattern to search for
#   $3 - Replacement text for the first matching line
replace_all_matching_lines() {
    [[ -z "$1" || -z "$2" ]] && return

    # Use sed to replace the first occurrence of a line matching $2 with $3 in $1
    sed -i "s/$2/$3/g" "$1"
}