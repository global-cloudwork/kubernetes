#!/usr/bin/env bash

# title()   : Bright white, underlined title
# section() : Cyan-colored section header
# header()  : Blue-colored, italicized subheader
# error()   : Bright red "Error:" message
# note()    : Bright green "Note:" message

title()   { printf "\033[1;4;38;5;231m# %s\033[0m\n" "$1"; }   # Bright white
section() { printf "\033[1;38;5;51m# %s\033[0m\n" "$1"; }       # Cyan
header()  { printf "\033[1;3;38;5;33m## %s\033[0m\n" "$1"; }    # Blue
error()   { printf "\033[1;4;38;5;196mError:\033[0m \033[1m%s\033[0m\n" "$1"; }  # Bright red
note()    { printf "\033[1;3;38;5;82mNote:\033[0m \033[1m%s\033[0m\n" "$1"; }   # Bright green

header "Importing environment variables from Google Secret Manager"
export $(gcloud secrets versions access latest --secret=development-env-file | xargs)
