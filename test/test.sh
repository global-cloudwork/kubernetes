MYVAR="one
two
three"

# echo "$MYVAR" | while read line; do
#   echo "Line: $line"
# done

# echo "$MYVAR"

echo_string() {
local input="$1"
echo "$input"
}


append_lines_to_file() {
    # $1 = filename
    # $2 = multiline string

    # Negate the AND: return if file not writable OR text is empty
    if ! [[ -w "$1" && -n "$2" ]]; then
      echo "Error: File not writable or text is empty." >&2
      exit 1
    fi

    # Append each line safely
    while IFS= read -r current; do
      echo $current
      printf "%s\n" "$current" >> "$1"
    done <<< "$2"
}

test="hello
my
name
is
josh"

if [[ -w "./test.txt" ]]; then
  echo "Writable"
else
  echo "Not writable"
fi

append_lines_to_file ./test.txt "$test"

# touch ./test.txt && echo "wrote file" || echo "no file written"




