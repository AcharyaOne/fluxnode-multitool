#!/bin/bash
set +o history
TMUX=$(command -v tmux) || { echo "This script requires tmux. Please install it."; exit 1; }
SESSION="FLUX-$$"
LAYOUT="tiled"

# Log files and their titles
declare -A FILES

FILES+=(
    [Watchdog]="/dat/usr/lib/fluxwatchdog/watchdog_error.log"
    [FluxD]="/dat/var/lib/fluxd/debug.log"
    [BenchMark]="/dat/usr/lib/fluxbenchd/debug.log"
    [FluxOS]="/dat/usr/lib/fluxos/debug.log"
)

# Cleanup function
function at_exit() {
    $TMUX kill-session -t "$SESSION" >/dev/null 2>&1
}

# Trap SIGINT (Ctrl+C) and SIGTERM to cleanup
trap at_exit SIGINT SIGTERM EXIT

VALID_FILES=()
for title in "${!FILES[@]}"; do
    LOG_FILE="${FILES[$title]}"
    if [ -f "$LOG_FILE" ]; then
        VALID_FILES+=("$title")
    fi
done

# Exit if no valid log files are found
if [ "${#VALID_FILES[@]}" -eq 0 ]; then
    echo "No valid log files found. Exiting."
    echo -e ""
    exit 1
fi

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

# Create panes for each log file
for title in "${!FILES[@]}"; do
    LOG_FILE="${FILES[$title]}"
    if [ -f "$LOG_FILE" ]; then
        $TMUX split-window -t "$SESSION" "printf '\033]2;%s\033\\' '${title}' ; sudo tail -F '${LOG_FILE}'"
        $TMUX select-layout -t "$SESSION" "$LAYOUT"
    else
        echo "Skipping ${title}: File not found (${LOG_FILE})"
    fi
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
