#!/bin/bash
#
# DO NOT PUT ANYTHING UP HERE
#
# We're recommending running the instaler through
# curl, piping the output to "sh", which may or may
# not be "bash" itself, the following detects this
# and ensures the rest of the script is run in "bash".
#
# Check to see if stdin is attached to a pipe
# sh, if so exec bash from here on out
# e.g. curl https://shakeit.co | sh
if test -p /dev/stdin; then
  exec bash
fi

set -e

readonly ANSI_BOLD='\033[1m'
readonly ANSI_RED='\033[38;5;9m'
readonly ANSI_GREEN='\033[38;5;10m'
readonly ANSI_PINK='\033[38;5;207m'
readonly ANSI_END='\033[0m'

readonly INSTALL_PATH="/usr/local/bin/shake"
readonly SHAKE_URL="https://raw.githubusercontent.com/shakeitco/shakeit/master/shake.bash"

#
#
#
function print_ansi {
  local IFS=
  printf "%b" "${*}${ANSI_END}"
}

#
#
#
function fatal_error {
  print_ansi "${ANSI_BOLD}${ANSI_RED}Error:"
  print_ansi " ${ANSI_RED}${*}\n"
  exit 1
}

#
#
#
function print_success {
  print_ansi "${ANSI_BOLD}${ANSI_GREEN}✓\n"
}

#
#
#
function print_failure {
  print_ansi "${ANSI_BOLD}${ANSI_RED}✗\n"
}

echo -e
echo -e "${ANSI_PINK}"
cat <<-BANNER
  ███████ ██   ██  █████  ██   ██ ███████
  ██      ██   ██ ██   ██ ██  ██  ██
  ███████ ███████ ███████ █████   █████
       ██ ██   ██ ██   ██ ██  ██  ██
  ███████ ██   ██ ██   ██ ██   ██ ███████
BANNER
echo -e "${ANSI_END}"
echo -e

printf "Checking PATH for /usr/local/bin..."
if [[ $PATH == */usr/local/bin* ]]; then
  print_success
else
  print_failure
  fatal_error "TODO: bad path"
fi

printf "Checking /usr/local/bin permissions..."
if test -w /usr/local/bin; then
  print_success
else
  print_failure
  fatal_error "TODO: no write permissions"
fi

printf "Downloading %bshake%b..." "${ANSI_BOLD}${ANSI_PINK}" "$ANSI_END"

if ! test -x "$(command -v curl)"; then
  print_failure
  fatal_error "TODO: curl not installed"
fi

if ! curl --silent "$SHAKE_URL" -o "$INSTALL_PATH"; then
  print_failure
  fatal_error "TODO: download failed"
fi

if test -f "$(command -v shake)"; then
  print_success
else
  print_failure
  fatal_error "TODO: file not written"
fi

printf "Setting file permissions..."
if chmod +x /usr/local/bin/shake; then
  print_success
else
  print_failure
  fatal_error "TODO: failed to set permissions"
fi

echo -e
print_ansi "${ANSI_GREEN}" "Successfully installed"
print_ansi "${ANSI_BOLD}${ANSI_PINK}" " shake"
echo -e "!"
echo -e

exec /usr/local/bin/shake -h
