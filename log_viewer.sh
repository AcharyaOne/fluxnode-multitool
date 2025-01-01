#!/bin/bash
set +o history

export NEWT_COLORS='
title=black,
'

TMUX=$(command -v tmux) || { echo "This script requires tmux. Please install it."; exit 1; }
SESSION="FLUX-$$"
LAYOUT="tiled"

# Log files and their titles
declare -A FILES
FILES+=(
    [Flux-Watchdog]="/dat/usr/lib/watchdog/watchdog_error.log"
    [Flux-Daemon]="/dat/var/lib/fluxd/debug.log"
    [Flux-Benchmark]="/dat/usr/lib/fluxbenchd/debug.log"
    [FluxOS]="/dat/usr/lib/fluxos/debug.log"
    [SAS-DEBUG]="/var/log/sas.log"
    [SAS-ERROR]="/var/log/sas-error.log"
    [MongoDB]="/dat/var/log/mongodb/mongod.log"
)

# Cleanup function
function at_exit() {
    $TMUX kill-session -t "$SESSION" >/dev/null 2>&1
    set -o history
}

# Trap SIGINT (Ctrl+C) and SIGTERM to cleanup
trap at_exit SIGINT SIGTERM EXIT

# Verify if all files exist and prepare the whiptail menu options
MENU_OPTIONS=()
for title in "${!FILES[@]}"; do
    LOG_FILE="${FILES[$title]}"
    if [ -f "$LOG_FILE" ]; then
        MENU_OPTIONS+=("$title" "                  " ON)
    else
        echo "Skipping ${title}: File not found (${LOG_FILE})"
    fi
done

# Exit if no valid log files are found
if [ "${#MENU_OPTIONS[@]}" -eq 0 ]; then
    echo -e "No valid log files found. Exiting."
    echo -e ""
    exit 1
fi

# Display whiptail menu
SELECTED_FILES=$(whiptail --title "Select Log Files" --checklist \
    "\nChoose which log files to monitor. Navigate using arrow keys, toggle selection with Spacebar, and confirm with Enter. To close the log monitor, press Ctrl+C.\n" 25 50 10 \
    "${MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)

# Handle user cancel or no selection
if [ $? -ne 0 ] || [ -z "$SELECTED_FILES" ]; then
    exit 1
fi

# Parse selected files into an array
SELECTED_FILES=($(echo "$SELECTED_FILES" | tr -d '"'))

# Start tmux session if it doesn't already exist
if ! $TMUX has-session -t "$SESSION" 2>/dev/null; then
    $TMUX new-session -d -s "$SESSION" -n Main "printf '\033]2;Main\033\\' ; bash"
else
    echo "Session $SESSION already exists. Attaching to it."
    $TMUX attach -t "$SESSION"
    exit 0
fi

# Enable mouse and adjust terminal overrides
$TMUX set-option -t "$SESSION" -q mouse on
$TMUX set-option -t "$SESSION" -ga terminal-overrides ',xterm*:smcup@:rmcup@'

# Create panes for each selected file
for title in "${SELECTED_FILES[@]}"; do
    LOG_FILE="${FILES[$title]}"
    echo "Opening pane for: $title ($LOG_FILE)"
    if sudo jq empty ${LOG_FILE} > /dev/null 2>&1; then
       $TMUX split-window -t "$SESSION" "printf '\033]2;%s\033\\' '${title}' ; sudo tail -F '${LOG_FILE}' | jq ."
    else
      $TMUX split-window -t "$SESSION" "printf '\033]2;%s\033\\' '${title}' ; sudo tail -F '${LOG_FILE}'"
    fi
    $TMUX select-layout -t "$SESSION" "$LAYOUT"
done

# Remove the initial empty pane
$TMUX kill-pane -t "${SESSION}.0"

# Final tmux layout adjustments
$TMUX select-layout -t "$SESSION" "$LAYOUT"

# Customize tmux appearance
$TMUX set-option -t "$SESSION" -g status-style bg=colour235,fg=yellow,dim
$TMUX set-window-option -t "$SESSION" -g window-status-style fg=brightblue,bg=colour236,dim
$TMUX set-window-option -t "$SESSION" -g window-status-current-style fg=brightred,bg=colour236,bright

# Synchronize panes for uniform control
$TMUX set-window-option -t "$SESSION" synchronize-panes on
$TMUX set-option -t "$SESSION" pane-border-status bottom

# Attach to the tmux session
$TMUX attach -t "$SESSION" >/dev/null 2>&1
