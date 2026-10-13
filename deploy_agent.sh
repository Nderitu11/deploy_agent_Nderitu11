#!/usr/bin/env bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
cd "$SCRIPT_DIR" || { echo "ERROR: cannot enter $SCRIPT_DIR"; exit 1; }

PROJECT_DIR=""     
DEPLOYING=0        


is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

die() { echo "ERROR: $*" >&2; exit 1; }


confirm() {
    local ans
    while true; do
        read -r -p "$1 [y/n]: " ans
        case "${ans,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}


ask_number() {
    local prompt="$1" min="$2" max="$3" val
    while true; do
        read -r -p "$prompt" val
        if is_int "$val" && [ "$val" -ge "$min" ] && [ "$val" -le "$max" ]; then
            REPLY_NUM="$val"
            return 0
        fi
        echo "Invalid input: enter a whole number between $min and $max."
    done
}


handle_interrupt() {
    trap '' INT TSTP          
    echo
    echo "!! Deployment interrupted by user."
    if [ "$DEPLOYING" -eq 1 ] && [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        local zipfile="${PROJECT_DIR}_archive.zip"
        echo "Archiving incomplete project to $zipfile ..."
        if zip -rq "$zipfile" "$PROJECT_DIR"; then
            echo "Archive created: $SCRIPT_DIR/$zipfile"
            rm -rf "$PROJECT_DIR" && echo "Removed incomplete directory: $PROJECT_DIR"
        else
            echo "WARNING: zip failed; keeping $PROJECT_DIR so nothing is lost."
        fi
    else
        echo "Nothing had been created yet, so there is nothing to archive."
    fi
    echo "Session closed."
    exit 130
}


choose_project() {
    local name
    echo "Existing projects:"
    ls -d attendance_tracker_*/ 2>/dev/null | sed 's#/$##; s#^#  - #' \
        || true
    read -r -p "Enter the project name (the part after attendance_tracker_): " name
    [ -n "$name" ] || die "Project name cannot be empty."
    PROJECT_DIR="attendance_tracker_${name}"
    [ -d "$PROJECT_DIR" ] || die "Project directory '$PROJECT_DIR' does not exist. Deploy it first."
}


preflight() {
    echo "== Pre-flight checks =="
    local missing=0 tool
    for tool in python3 zip; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "  [OK] $tool found"
        else
            echo "  [MISSING] $tool is not installed"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || die "Install the missing tool(s) and try again."
    python3 --version || die "python3 is installed but 'python3 --version' failed."
    for f in attendance_checker.py assets.csv config.json; do
        [ -r "$TEMPLATES/$f" ] || die "Template missing or unreadable: templates/$f"
    done
    [ -w "$SCRIPT_DIR" ] || die "No write permission in $SCRIPT_DIR."
}

build_roster_template() {
    local max count
    max=$(( $(wc -l < "$TEMPLATES/assets.csv") - 1 ))
    ask_number "How many students to copy (1-$max)? " 1 "$max"
    count="$REPLY_NUM"
    head -n $((count + 1)) "$TEMPLATES/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv" \
        || die "Could not write Helpers/assets.csv"
    TOTAL_SESSIONS=5
}

build_roster_fresh() {
    local names=("Alice Johnson" "Bob Smith" "Carol White" "David Brown" "Eve Davis"
                 "Frank Miller" "Grace Wilson" "Henry Moore" "Irene Taylor" "Jack Anderson"
                 "Karen Thomas" "Leo Jackson" "Maria Harris" "Nathan Martin" "Olivia Clark"
                 "Peter Lewis" "Quinn Walker" "Rachel Hall" "Samuel Young" "Tina King")
    local emails=(alice bob carol david eve frank grace henry irene jack
                  karen leo maria nathan olivia peter quinn rachel samuel tina)
    local n i idx round email
    ask_number "How many students to generate (1-100)? " 1 100
    n="$REPLY_NUM"
    {
        echo "Email,Names,Attendance Count,Absence Count"
        for ((i = 0; i < n; i++)); do
            idx=$((i % ${#names[@]}))
            round=$((i / ${#names[@]}))
            email="${emails[$idx]}"
            [ "$round" -gt 0 ] && email="${email}$((round + 1))"
            echo "${email}@example.com,${names[$idx]},0,0"
        done
    } > "$PROJECT_DIR/Helpers/assets.csv" || die "Could not write Helpers/assets.csv"
    TOTAL_SESSIONS=1
}

update_thresholds() {
    local cfg="$PROJECT_DIR/Helpers/config.json" warn fail
    confirm "Do you want to update the attendance alert thresholds?" || return 0
    while true; do
        read -r -p "Warning threshold % [default 75]: " warn
        warn="${warn:-75}"
        read -r -p "Failure threshold % [default 50]: " fail
        fail="${fail:-50}"
        if ! is_int "$warn" || ! is_int "$fail"; then
            echo "Both values must be whole numbers. Try again."
        elif [ "$warn" -gt 100 ] || [ "$fail" -gt 100 ]; then
            echo "Values must be between 0 and 100. Try again."
        elif [ "$fail" -ge "$warn" ]; then
            echo "Failure threshold must be lower than the warning threshold. Try again."
        else
            break
        fi
    done
    # Edit only the two target lines, in place, without reformatting the file.
    sed -i.bak -E "s/(\"warning\":[[:space:]]*)[0-9]+/\1${warn}/; s/(\"failure\":[[:space:]]*)[0-9]+/\1${fail}/" "$cfg" \
        || die "sed failed to update thresholds."
    rm -f "$cfg.bak"
    echo "Thresholds updated: warning=$warn, failure=$fail"
}

deploy() {
    local name
    preflight

    echo
    read -r -p "Enter a name for the project (creates attendance_tracker_<name>): " name
    [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || die "Invalid name. Use only letters, digits, '_' or '-'."
    PROJECT_DIR="attendance_tracker_${name}"

    if [ -e "$PROJECT_DIR" ]; then
        echo "'$PROJECT_DIR' already exists."
        if confirm "Overwrite it?"; then
            rm -rf "$PROJECT_DIR" || die "Could not remove existing '$PROJECT_DIR' (permission denied?)."
        else
            PROJECT_DIR=""
            die "Aborted: existing project left untouched."
        fi
    fi

    
    DEPLOYING=1
    trap handle_interrupt INT TSTP

    echo "Creating directory structure..."
    mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" \
        || die "Could not create directories (permission denied?)."

    cp "$TEMPLATES/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py" \
        || die "Could not copy attendance_checker.py"
    cp "$TEMPLATES/config.json" "$PROJECT_DIR/Helpers/config.json" \
        || die "Could not copy config.json"

    echo
    echo "How should the roster (Helpers/assets.csv) be built?"
    echo "  A) Copy rows from templates/assets.csv"
    echo "  B) Generate a fresh roster (all counts start at 0)"
    local choice
    while true; do
        read -r -p "Choose A or B: " choice
        case "${choice^^}" in
            A) build_roster_template; break ;;
            B) build_roster_fresh;    break ;;
            *) echo "Please enter A or B." ;;
        esac
    done

    
    sed -i.bak -E "s/(\"total_sessions\":[[:space:]]*)[0-9]+/\1${TOTAL_SESSIONS}/" \
        "$PROJECT_DIR/Helpers/config.json" || die "sed failed on total_sessions."
    rm -f "$PROJECT_DIR/Helpers/config.json.bak"
    echo "total_sessions set to $TOTAL_SESSIONS"

    echo
    chmod +x "$PROJECT_DIR/attendance_checker.py" || die "chmod +x failed."
    chmod 600 "$PROJECT_DIR/Helpers/config.json" || die "chmod 600 failed."
    echo "Permissions set:"
    ls -l "$PROJECT_DIR/attendance_checker.py" "$PROJECT_DIR/Helpers/config.json"

    echo
    update_thresholds

    
    DEPLOYING=0
    trap - INT TSTP

    echo
    echo "Deployment complete: $PROJECT_DIR"
    echo "Verifying deployment by launching the application..."
    run_app "$PROJECT_DIR"
}


run_app() {
    local dir="$1"
    [ -f "$dir/attendance_checker.py" ] || die "attendance_checker.py not found in $dir"
    ( cd "$dir" && python3 attendance_checker.py )
    local rc=$?
    [ "$rc" -eq 0 ] || echo "Application exited with status $rc."
}


archive_logs() {
    local ts src dest name found=0
    choose_project
    ts="$(date +%Y%m%d_%H%M%S)"

    for name in attendance absent; do
        src="$PROJECT_DIR/reports/${name}.log"
        dest="$PROJECT_DIR/archives/${name}/${name}_${ts}.log"
        if [ -f "$src" ]; then
            if mkdir -p "$PROJECT_DIR/archives/${name}" && mv "$src" "$dest"; then
                echo "Archived ${name}.log -> $dest"
                found=1
            else
                echo "ERROR: could not archive $src (permission denied?)" >&2
            fi
        else
            echo "No ${name}.log found in $PROJECT_DIR/reports/ - skipped."
        fi
    done
    [ "$found" -eq 1 ] || echo "No logs were archived."
}


menu() {
    local c
    while true; do
        echo
        echo "===== Attendance Tracker Deploy Agent ====="
        echo "1) Deploy the application"
        echo "2) Run the application"
        echo "3) Archive log files"
        echo "4) Exit"
        read -r -p "Select an option: " c
        case "$c" in
            1) deploy ;;
            2) choose_project; run_app "$PROJECT_DIR" ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid option." ;;
        esac
    done
}

case "$1" in
    --deploy)  deploy ;;
    --run)     choose_project; run_app "$PROJECT_DIR" ;;
    --archive) archive_logs ;;
    "")        menu ;;
    *)         echo "Usage: $0 [--deploy|--run|--archive]"; exit 1 ;;
esac
