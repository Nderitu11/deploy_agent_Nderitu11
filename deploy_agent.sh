#!/bin/bash
cd "$(dirname "$0")" || exit 1

PROJECT_DIR=""
DEPLOYING=0
TOTAL_SESSIONS=5
error() {
    echo "ERROR: $1"
    exit 1
}

confirm() {
    local answer
    read -r -p "$1 (y/n): " answer

    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
ask_number() {
    local answer
    local min="$1"
    local max="$2"

    while true
    do
        read -r -p "$3" answer

        if [[ "$answer" =~ ^[0-9]+$ ]] &&
           [ "$answer" -ge "$min" ] &&
           [ "$answer" -le "$max" ]; then
            REPLY_NUM="$answer"
            return
        fi

        echo "Enter a whole number between $min and $max."
    done
}

handle_interrupt() {
    trap - INT TSTP
    echo
    echo "Deployment interrupted!"

    if [ "$DEPLOYING" -eq 1 ] && [ -d "$PROJECT_DIR" ]; then
        echo "Creating ZIP archive..."

        if zip -rq "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR"; then
            echo "Archive created: ${PROJECT_DIR}_archive.zip"
            rm -rf "$PROJECT_DIR"
            echo "Incomplete project removed."
        else
            echo "ZIP failed. Keeping the project directory."
        fi
    else
        echo "No incomplete project to archive."
    fi

    exit 130
}

preflight() {
    for tool in python3 zip
    do
        if ! command -v "$tool" >/dev/null 2>&1; then
            error "$tool is not installed."
        fi
    done

    python3 --version || error "Python check failed."

    for file in attendance_checker.py assets.csv config.json
    do
        if [ ! -r "templates/$file" ]; then
            error "Missing template: templates/$file"
        fi
    done

    if [ ! -w "." ]; then
        error "No permission to write in this directory."
    fi

    echo "Pre-flight checks passed."
}

choose_project() {
    local name

    read -r -p "Enter the project name (without attendance_tracker_): " name

    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Invalid project name."
        return 1
    fi

    PROJECT_DIR="attendance_tracker_$name"

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Project not found. Deploy it first."
        return 1
    fi
}


build_roster_template() {
    local max count

    max=$(($(wc -l < templates/assets.csv) - 1))

    if [ "$max" -lt 1 ]; then
        error "The roster template has no student rows."
    fi

    ask_number 1 "$max" "How many students should be copied? "
    count="$REPLY_NUM"

    head -n "$((count + 1))" templates/assets.csv \
        > "$PROJECT_DIR/Helpers/assets.csv" ||
        error "Could not create the roster."

    TOTAL_SESSIONS=5
}

build_roster_fresh() {
    local names=("Alice Johnson" "Bob Smith" "Carol White" "David Brown"
                 "Eve Davis" "Frank Miller" "Grace Wilson" "Henry Moore"
                 "Irene Taylor" "Jack Anderson")

    local emails=("alice" "bob" "carol" "david" "eve"
                  "frank" "grace" "henry" "irene" "jack")

    local count i index email

    ask_number 1 100 "How many students should be generated? "
    count="$REPLY_NUM"

    echo "Email,Names,Attendance Count,Absence Count" \
        > "$PROJECT_DIR/Helpers/assets.csv"

    for ((i=0; i<count; i++))
    do
        index=$((i % 10))
        email="${emails[$index]}"

        if [ "$i" -ge 10 ]; then
            email="${email}$((i / 10 + 1))"
        fi

        echo "${email}@example.com,${names[$index]},0,0" \
            >> "$PROJECT_DIR/Helpers/assets.csv"
    done

    TOTAL_SESSIONS=1
}

update_thresholds() {
    local warning failure

    if ! confirm "Update attendance thresholds?"; then
        return
    fi

    while true
    do
        read -r -p "Warning percentage (default 75): " warning
        read -r -p "Failure percentage (default 50): " failure

        warning="${warning:-75}"
        failure="${failure:-50}"

        if [[ "$warning" =~ ^[0-9]+$ ]] &&
           [[ "$failure" =~ ^[0-9]+$ ]] &&
           [ "$warning" -le 100 ] &&
           [ "$failure" -le 100 ] &&
           [ "$failure" -lt "$warning" ]; then
            break
        fi

        echo "Enter numbers from 0 to 100. Failure must be lower than warning."
    done

    sed -i -E \
        "s/(\"warning\":[[:space:]]*)[0-9]+/\1$warning/" \
        "$PROJECT_DIR/Helpers/config.json" ||
        error "Could not update warning threshold."

    sed -i -E \
        "s/(\"failure\":[[:space:]]*)[0-9]+/\1$failure/" \
        "$PROJECT_DIR/Helpers/config.json" ||
        error "Could not update failure threshold."

    echo "Thresholds updated."
}

run_app() {
    if [ ! -f "$PROJECT_DIR/attendance_checker.py" ]; then
        echo "Application file not found."
        return 1
    fi

    echo "Starting attendance tracker..."
    (cd "$PROJECT_DIR" && python3 attendance_checker.py)
}

deploy() {
    local name choice

    preflight

    read -r -p "Enter a project name: " name

    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Use letters, numbers, underscores or hyphens."
        return
    fi

    PROJECT_DIR="attendance_tracker_$name"

    if [ -e "$PROJECT_DIR" ]; then
        if confirm "Project exists. Overwrite it?"; then
            rm -rf "$PROJECT_DIR" ||
                error "Could not remove the existing project."
        else
            echo "Deployment cancelled."
            return
        fi
    fi

    DEPLOYING=1
    trap handle_interrupt INT TSTP

    mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" ||
        error "Could not create project directories."

    cp templates/attendance_checker.py "$PROJECT_DIR/" ||
        error "Could not copy Python application."

    cp templates/config.json "$PROJECT_DIR/Helpers/" ||
        error "Could not copy configuration."

    echo "Choose how to create the roster:"
    echo "A. Copy students from the template"
    echo "B. Generate new students"

    while true
    do
        read -r -p "Choose A or B: " choice

        case "$choice" in
            A|a)
                build_roster_template
                break
                ;;
            B|b)
                build_roster_fresh
                break
                ;;
            *)
                echo "Choose A or B."
                ;;
        esac
    done

    sed -i -E \
        "s/(\"total_sessions\":[[:space:]]*)[0-9]+/\1$TOTAL_SESSIONS/" \
        "$PROJECT_DIR/Helpers/config.json" ||
        error "Could not update total sessions."

    chmod +x "$PROJECT_DIR/attendance_checker.py" ||
        error "Could not set application permissions."

    chmod 600 "$PROJECT_DIR/Helpers/config.json" ||
        error "Could not protect configuration."

    echo "Application is executable."
    echo "Configuration is restricted to owner read/write."

    update_thresholds

    DEPLOYING=0
    trap - INT TSTP

    echo "Deployment complete!"
    run_app
}

archive_logs() {
    local timestamp name source destination found=0

    choose_project || return

    timestamp=$(date +%Y%m%d_%H%M%S)

    for name in attendance absent
    do
        source="$PROJECT_DIR/reports/$name.log"
        destination="$PROJECT_DIR/archives/$name/${name}_${timestamp}.log"

        if [ -f "$source" ]; then
            mkdir -p "$PROJECT_DIR/archives/$name" ||
                error "Could not create archive directory."

            if mv "$source" "$destination"; then
                echo "Archived: $destination"
                found=1
            else
                echo "Could not archive $source."
            fi
        else
            echo "No $name.log found. Skipping."
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "No logs were archived."
    fi
}

while true
do
    echo
    echo "Attendance Tracker Deploy Agent"
    echo "1. Deploy application"
    echo "2. Run application"
    echo "3. Archive logs"
    echo "4. Exit"

read -r -p "Choose an option: " choice

    case "$choice" in
        1) deploy ;;
        2)
            if choose_project; then
                run_app
            fi
            ;;
        3) archive_logs ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *) echo "Invalid option." ;;
    esac
done

