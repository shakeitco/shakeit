#!/bin/bash

set -e

# Console colors
readonly ANSI_GREEN='\033[38;5;10m'
readonly ANSI_GRAY='\033[38;5;246m'
readonly ANSI_PINK='\033[38;5;207m'
readonly ANSI_BOLD='\033[1m'
readonly ANSI_END='\033[0m'
readonly COLOR_DEBUG='\033[1;36m'
readonly COLOR_INFO='\033[0;32m'
readonly COLOR_WARN='\033[1;33m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_INSTRUCTIONS='\033[0;37m'

# Log levels
readonly LOG_LEVEL_DEBUG="DEBUG"
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_WARN="WARN"
readonly LOG_LEVEL_ERROR="ERROR"
readonly DEFAULT_LOG_LEVEL="$LOG_LEVEL_INFO"
readonly LOG_LEVELS=("$LOG_LEVEL_DEBUG" "$LOG_LEVEL_INFO" "$LOG_LEVEL_WARN" "$LOG_LEVEL_ERROR")

# App specific
readonly DEFAULT_PROJECT_ROOT="$PWD"
readonly DEFAULT_COMMANDS_DIRNAME="scripts";
readonly DEFAULT_COMMAND_PREFIX="cmd-"

# Shake constants
readonly CONFIG_FILENAME="Shakefile"
readonly INIT_COMMAND="init"
readonly CREATE_COMMAND="create"
readonly EDIT_COMMAND="edit"
readonly DELETE_COMMAND="delete"
readonly HELP_COMMAND="help"
readonly CMD_COMMAND="cmd"
readonly TEST_COMMAND="test"
readonly DEFAULT_COMMAND="$HELP_COMMAND"

# Global variables only set by the corresponding configure_XXX function
COMMANDS=""
CONFIG_FILE=""
COMMANDS_DIR=""
LOG_LEVEL="$DEFAULT_LOG_LEVEL"
PROJECT_ROOT="$DEFAULT_PROJECT_ROOT"
COMMANDS_DIRNAME="$DEFAULT_COMMANDS_DIRNAME"
COMMAND_PREFIX="$DEFAULT_COMMAND_PREFIX"

# ██    ██ ████████ ██ ██      ██ ████████ ██    ██
# ██    ██    ██    ██ ██      ██    ██     ██  ██
# ██    ██    ██    ██ ██      ██    ██      ████
# ██    ██    ██    ██ ██      ██    ██       ██
#  ██████     ██    ██ ███████ ██    ██       ██

#
# Dumps a 'stack trace' for failed assertions.
#
function backtrace {
  local -r max_trace=20
  local frame=0
  while test $frame -lt $max_trace ; do
    frame=$((frame + 1))
    local bt_file=${BASH_SOURCE[$frame]}
    local bt_function=${FUNCNAME[$frame]}
    local bt_line=${BASH_LINENO[$frame-1]}  # called 'from' this line
    if test -n "${bt_file}${bt_function}" ; then
      log_error "  at ${bt_file}:${bt_line} ${bt_function}()"
    fi
  done
}

#
# Usage: assert_non_empty VAR
#
# Asserts that VAR is not empty and exits with an error code if it is.
#
function assert_non_empty {
  local -r var="$1"

  if test -z "$var" ; then
    log_error "internal error: unexpected empty-string argument"
    backtrace
    exit 1
  fi
}

#
# Usage: index_of VALUE ARRAY
#
# Returns the first index where VALUE appears in ARRAY. If ARRAY does not
# contain VALUE, returns -1.
#
# Examples:
#
# arr=("abc" "foo" "def")
# index_of foo "${arr[@]}"
#   Returns: 1
#
# arr=("abc" "def")
# index_of foo "${arr[@]}"
#   Returns -1
#
# index_of foo "abc" "def" "foo"
#   Returns 2
#
function index_of {
  local -r value="$1"
  shift
  local -r array=("$@")
  local i=0

  for (( i = 0; i < ${#array[@]}; i++ )); do
    if [ "${array[$i]}" = "${value}" ]; then
      echo $i
      return
    fi
  done

  echo -1
}

#
# Usage: search_up FILE_NAME START_DIR UP_TO_DIR
#
# Searches up the directory hierarchy for a given file.
# Returns the FILE_PATH of the resulting file
#
function search_up {
  local -r file_name="$1"
  local -r start_dir="$2"
  local -r up_to_dir="$3"

  while true; do
    if test -e "$file_name"; then
      echo "$PWD/$file_name"
      break
    fi
    if [[ "$PWD" == "$up_to_dir" || "$PWD" == "/" ]]; then
      break
    fi
    cd ..
  done

  cd "$start_dir"
}

#
# Usage: indirect_set VAR_NAME  VALUE
#
# Sets a variable given VAR_NAME to VALUE
#
function indirect_set {
  if ! unset -v "$1"; then
    log_error "Invalid identifier: $1"
    exit 1
  fi
  printf -v "$1" "%s" "$2"
}

#
# Usage: read_with_buffer VAR PROMPT INPUT_BUFFER
#
# Simulates Bash 4's ability to perform a readline read with a
# prepopulated input buffer. Given a PROMPT and INPUT_BUFFER the
# user can backspace up the INPUT_BUFFER. The VAR argument is a string
# that is indirectly set via indirect_set.
#
function read_with_buffer {
  # Might need this at some point
  # oldstty=$(stty -g)
  # trap "stty $oldstty" EXIT

  local "$1" # our return variable (see indirect_set)
  local char
  local value="$3"

  local -r backspace=$'\177'
  local -r enter=$'\r'

  # print prompt
  printf "%b" "$2$3"

  stty -icanon min 1 time 0 -icrnl -echo
  while true; do
    char="$(dd bs=10 count=1 2> /dev/null)"
    [ -z "$char" ] && continue

    case $char in
      $backspace)
      if [[ ${#value} -gt 0 ]]; then
        value=${value:0:${#value}-1}
        echo -n $'\b \b'
      fi
      ;;
      $enter)
      echo -e
      break
      ;;
      *)
      # printf "%q" "$char" # debug output
      printable=$(printf "%q" "$char")
      if [[ "$printable" == "$char" ]]; then
        value="${value}${char}"
        echo -n "$char"
      fi
      ;;
    esac
  done

  stty icanon echo icrnl

  indirect_set "$1" "$value"
}

# ██       ██████   ██████   ██████  ██ ███    ██  ██████
# ██      ██    ██ ██       ██       ██ ████   ██ ██
# ██      ██    ██ ██   ███ ██   ███ ██ ██ ██  ██ ██   ███
# ██      ██    ██ ██    ██ ██    ██ ██ ██  ██ ██ ██    ██
# ███████  ██████   ██████   ██████  ██ ██   ████  ██████

# Helper function to log an INFO message. See the log function for details.
function log_info {
  log "$COLOR_INFO" "$ANSI_END" "$LOG_LEVEL_INFO" "$@"
}

# Helper function to log a WARN message. See the log function for details.
function log_warn {
  log "$COLOR_WARN" "$ANSI_END" "$LOG_LEVEL_WARN" "$@"
}

# Helper function to log a DEBUG message. See the log function for details.
function log_debug {
  log "$COLOR_DEBUG" "$ANSI_END" "$LOG_LEVEL_DEBUG" "$@"
}

# Helper function to log an ERROR message. See the log function for details.
function log_error {
  log "$COLOR_ERROR" "$ANSI_END" "$LOG_LEVEL_ERROR" "$@"
}

#
# Usage: log COLOR ANSI_END LEVEL [MESSAGE ...]
#
# Logs MESSAGE surrounded by COLOR and ANSI_END, to stdout
# if the log level is at least LEVEL. If no MESSAGE is specified, reads from
# stdin.
#
# Examples:
#
# log "\033[0;32m" "\033[0m" "2015-06-03 15:30:33" "INFO" "Hello, World"
#   Prints: "\033[0;32m2015-06-03 15:30:33 [INFO] Hello, World\033[0m" to stdout.
#
# echo "Hello, World" | log "\033[0;32m" "\033[0m" "2015-06-03 15:30:33" "ERROR"
#   Prints: "\033[0;32m2015-06-03 15:30:33 [ERROR] Hello, World\033[0m" to stdout.
#
function log {
  if [[ "$#" -gt 3 ]]; then
    do_log "$@"
  elif [[ "$#" -eq 3 ]]; then
    local message=""
    while read -r message; do
      do_log "$1" "$2" "$3" "$4" "$message"
    done
  else
    echo "Internal error: invalid number of arguments passed to log function: $*"
    exit 1
  fi
}

#
# Usage: do_log COLOR ANSI_END LEVEL MESSAGE ...
#
# Logs MESSAGE surrounded by COLOR and ANSI_END, to stdout
# if the log level is at least LEVEL.
#
# Examples:
#
# do_log "\033[0;32m" "\033[0m" "INFO" "Hello, World"
#   Prints: "\033[0;32m[INFO] Hello, World\033[0m" to stdout.
#
function do_log {
  local -r color="$1"
  shift
  local -r color_end="$1"
  shift
  local -r log_level="$1"
  shift
  local -r message="$*"

  local -r log_level_index=$(index_of "$log_level" "${LOG_LEVELS[@]}")
  local -r current_log_level_index=$(index_of "$LOG_LEVEL" "${LOG_LEVELS[@]}")

  if [[ "$log_level_index" -ge "$current_log_level_index" ]]; then
    echo -e "${color}[${log_level}] ${message}${color_end}"
  fi
}

#  ██████  ██████  ███    ██ ███████ ██  ██████
# ██      ██    ██ ████   ██ ██      ██ ██
# ██      ██    ██ ██ ██  ██ █████   ██ ██   ███
# ██      ██    ██ ██  ██ ██ ██      ██ ██    ██
#  ██████  ██████  ██   ████ ██      ██  ██████

#
# Usage: configure_project_root
#
# Sets PROJECT_ROOT based on the dirname of CONFIG_FILE
#
function configure_project_root {
  local -r project_root=$(dirname "$CONFIG_FILE")
  if test -d "$project_root"; then
    PROJECT_ROOT="$project_root"
  fi
}

#
# Usage: configure_commands_dir
#
# Sets COMMANDS_DIR based on PROJECT_ROOT and COMMANDS_DIRNAME
#
function configure_commands_dir {
  COMMANDS_DIR="$PROJECT_ROOT/$COMMANDS_DIRNAME"
}

#
# Usage: configure_config_file
#
# Looks for a config file named CONFIG_FILENAME and sets CONFIG_FILE
#
function configure_config_file {
  local -r config_file=$(search_up "$CONFIG_FILENAME" "$PWD" "$HOME")
  if test -n "$config_file"; then
    CONFIG_FILE="$config_file"
  fi
}

#
# Usage: configure_commands COMMANDS_DIRNAME COMMAND_PREFIX
#
# Finds executable scripts under COMMANDS_DIRNAME that are both
# executable and have the COMMAND_PREFIX
#
function configure_commands {
  local -r commands_dir="$1"
  local -r command_prefix="$2"
  local commands=()

  local function_commands
  function_commands=($(compgen -A "function"| grep "$command_prefix" || true))

  local func_name cmd_name
  for func_name in "${function_commands[@]}"; do
    cmd_name=${func_name/${command_prefix}/}
    commands+=($cmd_name)
    # shellcheck disable=SC1091
    source /dev/stdin <<-EOF
    function __cmd_run_${cmd_name} {
      "$func_name" "\$@"
    }
    function __cmd_desc_${cmd_name} {
      parse_config_desc "$func_name"
    }
EOF
  done

  COMMANDS=("${commands[@]}")

  if test -d  "$commands_dir"; then
    local filepath path cmd_name
    while read -r filepath; do
      path=$(basename "$filepath")
      cmd_name=$(sed -E "s/^${command_prefix}([^.]+)\.?.*\$/\1/" <<< "$path")
      commands+=($cmd_name)
      # shellcheck disable=SC1091
      source /dev/stdin <<-EOF
      function __cmd_run_${cmd_name} {
        "$filepath" "\$@"
      }
      function __cmd_desc_${cmd_name} {
        parse_desc "$filepath"
      }
EOF
    done < <(find "$commands_dir" -maxdepth 1 -name "$command_prefix*" -type f -or -type l)
  fi

  COMMANDS=("${commands[@]}")
}

#
# Usage: configure_commands_dirname COMMANDS_DIRNAME
#
# Sets COMMANDS_DIRNAME global if not empty
#
function configure_commands_dirname {
  if test -n "$1"; then
    COMMANDS_DIRNAME="$1"
  fi
  assert_non_empty "$COMMANDS_DIRNAME"
}

#
# Usage: configure_command_prefix COMMAND_PREFIX
#
# Sets COMMAND_PREFIX global if not empty
#
function configure_command_prefix {
  if test -n "$1"; then
    COMMAND_PREFIX="$1"
  fi
  assert_non_empty "$COMMAND_PREFIX"
}

#
# Usage: configure_log_level LOG_LEVEL
#
# Sets LOG_LEVEL global if valid or reports error
#
function configure_log_level {
  case "$(awk '{print toupper($0)}' <<< "$1")" in
    "$LOG_LEVEL_DEBUG")
      LOG_LEVEL="$LOG_LEVEL_DEBUG"
      ;;
    "$LOG_LEVEL_INFO")
      LOG_LEVEL="$LOG_LEVEL_INFO"
      ;;
    "$LOG_LEVEL_ERROR")
      LOG_LEVEL="$LOG_LEVEL_ERROR"
      ;;
    "")
      LOG_LEVEL="$DEFAULT_LOG_LEVEL"
      ;;
    *)
      log_error "Invalid LOG_LEVEL=${1} specified"
      log_error "Valid levels: ${LOG_LEVELS[*]}"
      exit 1
      ;;
  esac

  assert_non_empty "$LOG_LEVEL"
}

#
# Usage: load_config
#
# Looks for a CONFIG_FILENAME by traversing up the file hierarchy, if one
# is not found then defaults are assumed
#
function load_config {
  # local values=()
  # local IFS=","

  configure_config_file
  configure_project_root


  if test -e "$CONFIG_FILE"; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi

  # configure_commands_dirname "${COMMANDS_DIRNAME}"
  # configure_command_prefix "${values[1]}"
  # configure_log_level "${values[2]}"

  configure_commands_dir
}

#  ██████ ██      ██
# ██      ██      ██
# ██      ██      ██
# ██      ██      ██
#  ██████ ███████ ██

#
# Executes no code or side effects. Used only at test time to make it easy to
# "source" this script.
#
function test_mode {
  return 0
}

#
# Usage: do_init_get_configuration
#
# Called by init. Used to continuously prompt users for new project
# configuration.
#
function do_init_get_configuration {
  # project root
  echo -e -n "$ANSI_BOLD"
  echo -e "#1) Choose a project root" "$ANSI_END"
  echo -e "    This directory will the top-most directory in your project"
  echo -e "    that will recognize your shake commands."
  echo -e
  echo -e "${ANSI_GREEN}TIP:${ANSI_END} You can run shake from any sub-directory of your project"
  echo -e
  while true; do
    read_with_buffer project_root "${ANSI_BOLD}root dir:${ANSI_END} " "$project_root"
    if test ! -w "$project_root"; then
      log_error "Project root $project_root does not have write permission"
    elif test -d "$project_root"; then
      project_root=${project_root%/}
      echo -e
      break
    else
      log_error "Project root $project_root not a directory"
    fi
  done

  # commands dir
  echo -e -n "$ANSI_BOLD"
  echo -e "#2) Specify a command-scripts directory" "$ANSI_END"
  echo -e "    This directory can be a new or existing one."
  echo -e "    It will be used by shake to locate command-scripts."
  echo -e
  echo -e "${ANSI_GREEN}TIP:${ANSI_END} Command-scripts are normal scripts that can be executed directly."
  echo -e "     It's common to choose a directory you already have and have command"
  echo -e "     scripts wrap existing sets of scripts or use common helpers."
  echo -e
  local -r prompt="${ANSI_BOLD}commands dir:${ANSI_END} ${ANSI_GRAY}$project_root/${ANSI_END}"
  while true; do
    read_with_buffer commands_dirname "$prompt" "$commands_dirname"
    if ! [[ "$commands_dirname" =~ ^/|\.\. ]]; then
      commands_dirname=${commands_dirname%/}
      echo -e
      break
    fi
    log_error "Must provide the name of a sub-directory"
  done

  echo -e -n "$ANSI_BOLD"
  echo -e "#3) Specify a command-script prefix" "$ANSI_END"
  echo -e "    This prefix is used by shake to separate command-scripts from other files in the"
  echo -e "    command-scripts directory. The prefix is not part of the name of the command."
  echo -e "    It's recommended to end the prefix with a \"-\", for example:"
  echo -e "      $ shake start-server # command-script: cmd-start-server"
  echo -e "      $ shake run-tests    # command-script: cmd-run-tests"
  echo -e
  echo -e "${ANSI_GREEN}TIP:${ANSI_END} You can edit existing or create new command-scripts by running:"
  echo -e "       $ shake --edit my-existing-command"
  echo -e "       $ shake --create some-new-command"
  echo -e
  while true; do
    read_with_buffer command_prefix "${ANSI_BOLD}command prefix:${ANSI_END} " "$command_prefix"
    if test -n "$command_prefix"; then
      break
    fi
    log_error "Must specify a prefix for commands"
  done

  echo -e
  echo -e "Confirm configuration:"
  echo -e
  echo -e "#1) ${ANSI_BOLD}root dir      ${ANSI_END} = ${project_root}"
  echo -e "#2) ${ANSI_BOLD}commands dir  ${ANSI_END} = ${commands_dirname}"
  echo -e "#3) ${ANSI_BOLD}command prefix${ANSI_END} = ${command_prefix}"
  echo -e
  local yes_or_no;
  read_with_buffer yes_or_no "${ANSI_BOLD}Does this look right?${ANSI_END} (y/n): " "y"
  if [[ "$yes_or_no" =~ ^(n|N) ]]; then
    do_init_get_configuration
  fi
}

#
# Usage: do_init_write_configuration
#
# Called by init. Writes configuration provided by do_init_get_configuration
#
function do_init_write_configuration {
  local config_file="${project_root}/${CONFIG_FILENAME}"
  cat > "$config_file" <<-EOF
COMMANDS_DIR="${commands_dirname}"
COMMAND_PREFIX="${command_prefix}"
EOF

  local commands_dir="${project_root}/${commands_dirname}"
  if ! test -d "$commands_dir"; then
    mkdir -p "$commands_dir"
  fi

  local example_command_file="${commands_dir}/${command_prefix}example"
  cat > "$example_command_file" <<-EOF
#!/bin/bash
# ^ This line is called the shebang, it points to a executable.
# When a command is executed it's processed by the shebang executable.
# Here are a few example:
# nodejs: #!/usr/bin/env node
# python: #!/usr/bin/env python
# custom: #!/path/to/my/executable

# DESC: shake example command, run "shake example" to execute it

echo
echo "Welcome to shake!"
echo

# Shake allows you to pass arguments to script-commands.
# This allows you to easily add flags or options to your script-commands,
# or pass them to another program you use to run.

if (( \$# == 0 )); then
  echo "Try passing an argument:"
  echo "  $ shake example hello"
else
  echo "First argument: \"\$1\""
fi
if (( \$# == 1 )); then
  echo
  echo "You can pass as many arguments (or flags) as you'd like."
  echo "Try this:"
  echo "  $ shake example hello --foo"
elif (( \$# > 1 )); then
  echo "Second argument: \"\$2\""
  echo "All arguments: \$*"
  echo
  echo "To edit this command-script, and for more information, run:"
  echo '  $ shake --edit example'
  echo
  echo "You can remove this command-script by running:"
  echo "  $ shake --delete example"
  echo
  echo "To create your own command-script, run:"
  echo "  $ shake --create my-command"
fi
echo
EOF
    chmod +x "${example_command_file}"
}

#
# Usage: init
#
# Initialzes the currend directory as a new shake project root,
# prompting the user for PROJECT_ROOT, COMMANDS_DIR and COMMAND_PREFIX.
#
function init {
  if test -n "$CONFIG_FILE"; then
    if [[ "$CONFIG_FILE" != "${PWD}/${CONFIG_FILENAME}" ]]; then
      echo -e
      log_warn "Existing shake config file in a parent directory:"
      log_warn "  $CONFIG_FILE"
      echo -e
    else
      log_error "Failed to init"
      log_warn "Path ${PROJECT_ROOT} already configured."
      log_info "To edit the config file, or a specific command, run:"
      log_info "  $ shake --edit [COMMAND]"
      return
    fi
  fi

  local project_root="$PWD";
  local commands_dirname="scripts";
  local command_prefix="cmd-";

  echo -e "$ANSI_GRAY"
  echo -e "This utility will walk you through the basic shake setup process."
  echo -e "It only covers the required configuration, and suggests typical defaults."
  echo -e
  echo -e "Press CTRL-C at any time to quit. No changes are made until you've finished."
  echo -e "$ANSI_END"

  do_init_get_configuration
  do_init_write_configuration

  clear
  main "-h"
}

#
# Usage: parse_desc COMMAND_NAME
#
# Parses the DESC line out of the command-script file
#
function parse_desc {
  local -r file="$1"
  local -r re="DESC: *([^$]+)$"
  local desc line

  while read -r line; do
    if [[ $line =~ $re ]]; then
      desc="${BASH_REMATCH[1]}"
      break
    fi
  done < "$file"

  echo "$desc"
}

function parse_config_desc {
  local -r func_name="$1"
  local -r config_file="$CONFIG_FILE"
  local -r fn_re="^(function ${func_name}(\(\))?)|(${func_name} *\(\)) +{"
  local -r desc_re="# *([^$]+)$"
  local line last_line desc

  while read -r line; do
    if [[ $line =~ $fn_re ]]; then
      if [[ $last_line =~ $desc_re ]]; then
        desc="${BASH_REMATCH[1]}"
      fi
      break
    fi
    last_line="$line"
  done < "$config_file"

  echo "$desc"
}

#
# Usage: print_help
#
# Prints the usage instructions for shake
#
function print_help {
  local -r commands_dir="$COMMANDS_DIR"
  local -r commands="${COMMANDS[*]}"

  # used for right pad below
  local padding=0
  for command in $commands; do
    if (( ${#command} > padding )); then
      padding=${#command}
    fi
  done

  echo -e
  echo -e "  shake ${ANSI_PINK}[OPTIONS] ${ANSI_GREEN}[COMMAND] ${ANSI_GRAY}[COMMAND-ARGS]${ANSI_END}"
  echo -e
  echo -e "${ANSI_BOLD}Options${ANSI_END}"
  echo -e
  echo -e "  ${ANSI_PINK}--init${ANSI_END}\tInitialize a new shake project"
  echo -e "  ${ANSI_PINK}-h${ANSI_END}, ${ANSI_PINK}--help${ANSI_END}\tPrint this help text and exit"
  echo -e
  if (( ${#commands} == 0 )); then
    if test -d "$commands_dir"; then
      echo -e "${ANSI_GRAY}No commands found in:${ANSI_END} $commands_dir"
      echo -e
      echo -e "To create a command, run:"
      echo -e " $ shake --create <command-name>"
    else
      echo -e "It appears this directory, or its parent directories,"
      echo -e "have not been setup to run shake."
      echo -e
      echo -e "To start using shake run:"
      echo -e "  $ shake --init"
    fi
  else
    echo -e "${ANSI_BOLD}Commands${ANSI_END}"
    echo -e
    local has_one_desc=false
    for command in $commands; do
      desc=$(__cmd_desc_${command})
      if [[ "$has_one_desc" == false && -n "$desc" ]]; then
        has_one_desc=true
      fi
      local nspaces=$(( padding + 2 - ${#command} ))
      printf "  %b%${nspaces}s%b\n" "${ANSI_GREEN}${command}${ANSI_END}" "" "$desc"
    done
    if ! ("$has_one_desc"); then
      echo -e
      echo -e "${ANSI_GREEN}TIP:${ANSI_END} You can add a description for your command by adding"
      echo -e "     a DESC line to your command-script, for example:"
      echo -e
      echo -e "       #!/bin/bash"
      echo -e "       # DESC: start the dev server"
      echo -e "       ..."
    fi
  fi
  echo -e
}

#
# Usage: create_command COMMAND_NAME
#
# Creates the command-script given a COMMAND_NAME, inside the COMMANDS_DIR
# with the specified COMMAND_PREFIX
#
function create_command {
  local -r command_name="$1"
  local -r commands_dir="$COMMANDS_DIR"
  local -r command_prefix="$COMMAND_PREFIX"
  local -r command_file="${commands_dir}/${command_prefix}${command_name}"

  if test -e "$command_file"; then
    log_error "Unable to create command \"$command_name\": already exists"
    log_info "To edit, run: $ shake --edit $command_name"
    exit 1
  elif test ! -w "$commands_dir"; then
    log_error "Unable to create command \"$command_name\": unable to write to \"$commands_dir\""
    exit 1
  fi

  cat > "$command_file" <<-EOF
#!/bin/bash
# DESC: (add a description for $command_name)

echo "Hello, $command_name"
EOF
  chmod +x "$command_file"

  edit_command "$command_name"
}

#
# Usage: edit_command COMMAND_NAME
#
# Opens the environment's EDITOR to the COMMAND_FILE based on the
# given COMMAND_NAME in the COMMANDS_DIR with the COMMAND_PREFIX
#
function edit_command {
  local -r command_name="$1"
  local -r commands_dir="$COMMANDS_DIR"
  local -r command_prefix="$COMMAND_PREFIX"
  local -r command_file="${commands_dir}/${command_prefix}${command_name}"
  local editor="${EDITOR-}"

  if test ! -e "$command_file"; then
    log_error "Unable to edit command \"$command_name\": does not exit"
    log_info "To create, run: $ shake --create $command_name"
    exit 1
  elif test ! -w "$command_file"; then
    log_error "Unable to edit command \"$command_name\": no write permission"
    exit 1
  fi

  if test -z "$editor"; then
    log_warn "EDITOR environment variable unset. Trying nano and vim..."
    if test -x "$(command -v nano)"; then
      editor="nano"
    elif test -x "$(command -v vim)"; then
      editor="vim"
    else
      log_error "Unable to find default editor. Try exporting an EDITOR environment variable."
      exit 1
    fi
  fi

  exec "$editor" "$command_file"
}

#
# Usage: delete_command COMMAND_NAME
#
# Prompts the user to remove the command given the COMMAND_NAME, based on
# the COMMANDS_DIR and COMMAND_PREFIX
#
function delete_command {
  local -r command_name="$1"
  local -r commands_dir="$COMMANDS_DIR"
  local -r command_prefix="$COMMAND_PREFIX"
  local -r command_file="${commands_dir}/${command_prefix}${command_name}"

  if test ! -e "$command_file"; then
    log_error "Unable to delete command \"$command_name\": does not exit"
    log_info "To create, run: $ shake --create $command_name"
    exit 1
  elif test ! -w "$command_file"; then
    log_error "Unable to delete command \"$command_name\": no write permission"
    exit 1
  fi

  local yes_or_no;
  echo -e
  echo -e "${COLOR_WARN}Request to remove:${ANSI_END}"
  echo -e
  echo -e "${ANSI_BOLD}Command:${ANSI_END}\t${command_name}"
  echo -e -n "${ANSI_BOLD}Description:${ANSI_END}"
  local -r desc="$(parse_desc "$command_name")"
  if test -n "$desc"; then
    echo -e "\t$desc"
  else
    echo -e "\t(No description)"
  fi
  echo -e -n "${ANSI_BOLD}File:${ANSI_END}"
  echo -e "\t\t${command_file}"
  echo -e

  local yes_or_no
  read_with_buffer yes_or_no "${ANSI_BOLD}Are you sure?${ANSI_END} (y/n): " ""
  if [[ "$yes_or_no" =~ ^(y|Y) ]]; then
    rm -f "$command_file"
    echo -e "Command/file successfully removed."
  else
    echo -e "Command/file were ${ANSI_BOLD}not${ANSI_END} removed."
  fi
  echo -e
}

#
# Usage: assert_valid_arg ARG ARG_NAME
#
# Asserts that ARG is not empty and is not a flag (i.e. starts with a - or --)
#
# Examples:
#
# assert_valid_arg "foo" "--my-arg"
#   returns 0
#
# assert_valid_arg "" "--my-arg"
#   prints error, instructions, and exits with error code 1
#
# assert_valid_arg "--foo" "--my-arg"
#   prints error, instructions, and exits with error code 1
#
function assert_valid_arg {
  local -r arg="$1"
  local -r arg_name="$2"

  if [[ -z "$arg" || "${arg:0:1}" = "-" ]]; then
    log_error "You must provide a value for argument $arg_name"
    instructions
    exit 1
  fi
}

#
#
#
#
#
function shake {
  local -r cmd_name="$1"
  "__cmd_run_${cmd_name}" "$@"
}

#
# Usage main ARGS ...
#
# Parses ARGS to kick off shake. See the output of the print_help
# function for details.
#
function main {
  load_config

  local commands_dir="$COMMANDS_DIR"
  local command_prefix="$COMMAND_PREFIX"
  local cmd="$DEFAULT_COMMAND"

  configure_commands "$commands_dir" "$command_prefix"

  local stop=false
  while [[ $# -gt 0 && $stop == false ]]; do
    key="$1"

    # Check if KEY is in COMMANDS and set CMD_MATCH if so
    [[ $(index_of "$key" "${COMMANDS[@]}") -ge 0 ]] && cmd_match="$key"

    case $key in
      $cmd_match) # matches if KEY in COMMANDS
        cmd="$CMD_COMMAND"
        stop=true # all remaining args go to command
        ;;
      --init)
        cmd="$INIT_COMMAND"
        stop=true # init overrides any command
        ;;
      -c|--create)
        cmd="$CREATE_COMMAND"
        assert_valid_arg "$2" "$key"
        local -r create_target="$2"
        shift
        ;;
      -e|--edit)
        cmd="$EDIT_COMMAND"
        assert_valid_arg "$2" "$key"
        local -r edit_target="$2"
        shift
        ;;
      -d|--delete)
        cmd="$DELETE_COMMAND"
        assert_valid_arg "$2" "$key"
        local -r delete_target="$2"
        shift
        ;;
      -h|--help)
        cmd="$HELP_COMMAND"
        stop=true # help overrides any command
        ;;
      test_mode)
        cmd="$TEST_COMMAND"
        stop=true
        ;;
      *)
      log_error "Unrecognized argument: $key"
      exit 1
      ;;
    esac
    shift
  done

  case "$cmd" in
    "$CMD_COMMAND")
      shake "$key" "$@"
      ;;
    "$CREATE_COMMAND")
      create_command "$create_target"
      ;;
    "$EDIT_COMMAND")
      edit_command "$edit_target"
      ;;
    "$DELETE_COMMAND")
      delete_command "$delete_target"
      ;;
    "$INIT_COMMAND")
      init
      ;;
    "$TEST_COMMAND")
      test_mode
      ;;
    "$HELP_COMMAND")
      print_help
      exit 0
      ;;
  esac
}

main  "$@"
