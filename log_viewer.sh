#!/bin/bash

set +o history
#
# Script to launch tmux in tiled mode with the most common log files being tailed
#

TMUX=$(type -p tmux) || { echo "This script requires tmux"; exit 1; }

SESSION="FLUX-$$"

NOKILL=0
LAYOUT=tiled

declare -A FILES
if [ -d "/dat" ]; then
    FILES+=(
        [4 Watchdog]="sudo tail -F /dat/usr/lib/fluxwatchdog/watchdog_error.log"
        [2 FluxD]="sudo tail -F /dat/var/lib/fluxd/debug.log"
        [3 BenchMark]="sudo tail -F /dat/usr/lib/fluxbenchd/debug.log"
        [1 FluxOS]="sudo tail -F /dat/usr/lib/fluxos/debug.log"
    )
fi

function at_exit() {
    $TMUX kill-session -t "$SESSION" >/dev/null 2>&1
}
[[ "$NOKILL" == "1" ]] || trap at_exit EXIT

$TMUX -q new-session -d -s "$SESSION" -n Main "printf '\033]2;Main\033\\' ; bash"

$TMUX set-option -t "$SESSION" -q mouse on

# Create panes for each file
for key in "${!FILES[@]}"; do
    # Extract file path from the command
    FILE_PATH=$(echo "${FILES[${key}]}" | awk '{print $NF}')
    
    if [ -e "$FILE_PATH" ]; then
        echo "Creating tmux pane for ${key}: ${FILES[${key}]}"  # Debugging output
        $TMUX -q split-window -t "$SESSION" "printf '\033]2;%s\033\\' '${key}' ; eval ${FILES[${key}]}"
        $TMUX -q select-layout -t "$SESSION" "$LAYOUT"
    else
        echo "Skipping ${key}: File not found (${FILE_PATH})"
    fi
done

# Ensure the first pane is removed
$TMUX -q kill-pane -t "${SESSION}.0"

# Final layout adjustments
$TMUX -q select-layout -t "$SESSION" "$LAYOUT"

# Set tmux options for appearance
$TMUX set-option -t "$SESSION" -g status-style bg=colour235,fg=yellow,dim
$TMUX set-window-option -t "$SESSION" -g window-status-style fg=brightblue,bg=colour236,dim
$TMUX set-window-option -t "$SESSION" -g window-status-current-style fg=brightred,bg=colour236,bright

$TMUX -q set-window-option -t "$SESSION" synchronize-panes on
$TMUX set-option -t "$SESSION" -w pane-border-status bottom

# Attach to the tmux session
$TMUX -q attach -t "$SESSION" >/dev/null 2>&1
