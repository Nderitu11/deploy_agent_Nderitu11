#!/bin/bash
deploy_application() {
	is_deploying=true
	echo "Starting deployment process"
        if ! command -v python3 &> /dev/null; then
	echo "[FATAL ERROR] python3 is not installed.Aborting."
        exit 1
        fi
        if !command -v zip &> /dev/null;then 
        echo" [FATAL ERROR] zip utility tool missing.Aborting."
        exit 1
        fi
	echo "[PASS] Verification successful."
               
}
run_application(){
	echo "Launching the application"
}
archive_logs(){
	echo "Archiving log files"
}
case "$1" in
	deploy)
		deploy_application
		;;
	run)
		run_application
		;;
	archive)
		archive_logs
		;;
	*)
                echo "Error: Please use one of the following commands:"
		echo "Usage: $0 {deploy|run|archive}"
		exit 1
	        ;;
esac



read -p "Enter a unique identifier project name: "proj_input
if [ "$proj_input" = "" ]; then
	echo "[ERROR]projectname cannot be empty."
else
TARGET_DIR="attendance_tracker_${proj_input}"
if [ -d "TARGET_DIR" ]; THEN
	read -p "[WARN] Directory'$TARGET_DIR' already exists.Overwrite it?(y/n): "overwrite_choice
	case "$overwite_choice" in
		[Yy]* )
			echo "[INFO] Cleaning up olddirectory track structure"
			rm -rf "$TARGET_DIR"
			;;
		    * )
			    echo "[INFO] Deployment cancelled."
			    exit 0
			    ;
	       esac
	     fi
             
	     mkdir -p "$TARGET_DIR/Helpers"
             mkdir -p "$TARGET_DIR/reports"
             mkdir -p "$TARGET_DIR/archives/attendance"
             mkdir -p "$TARGET_DIR/archives/absent"
             echo "[INFO] Created project directory tree layout."

	      if [ ! -f "templates/attendance_checker.py" ] || [ ! -f "templates/config.json" ] || [ ! -f "templates/assets.csv" ]; then
        echo "[ERROR] Missing source components inside your templates/ folder path directory."
        rm -rf "$TARGET_DIR"
        exit 1
    fi

  
    cp "templates/attendance_checker.py" "$TARGET_DIR/"
    cp "templates/config.json" "$TARGET_DIR/Helpers/"
    echo "[INFO] Successfully staged core Python script and configuration template parameters."
    # 3. Populate Source Files and Configure the Roster Database
    cp "templates/attendance_checker.py" "$TARGET_DIR/"
    cp "templates/config.json" "$TARGET_DIR/Helpers/"

    echo "Configure your student roster (Helpers/assets.csv):"
    echo "  Option A: Copy lines directly from templates/assets.csv"
    echo "  Option B: Generate a fresh, zero-count starting roster"
    read -p "Select your choice option (A/B): " roster_choice

    if [[ "$roster_choice" =~ ^[Aa]$ ]]; then
        read -p "How many students do you want to copy from the template? " num_students
        # Write out the clean column headers line first
        head -n 1 "templates/assets.csv" > "$TARGET_DIR/Helpers/assets.csv"
        if [ "$num_students" -gt 0 ]; then
            # Extract data records skipping the header line
            tail -n +2 "templates/assets.csv" | head -n "$num_students" >> "$TARGET_DIR/Helpers/assets.csv"
        fi
        echo "[INFO] Successfully imported $num_students entries from templates."

        # Set total sessions to 5 since Option A template data contains 4 prior sessions
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 5/' "$TARGET_DIR/Helpers/config.json"

    elif [[ "$roster_choice" =~ ^[Bb]$ ]]; then
        read -p "How many fresh zero-count students do you want to generate? " num_students

        # Schema framework column baseline headers
        echo "Email,Names,Attendance Count,Absence Count" > "$TARGET_DIR/Helpers/assets.csv"

        # Mock database arrays to construct fresh names dynamically
        sample_names=("John Doe" "Jane Smith" "Alex Jones" "Emma Watson" "David Miller" "Sarah Connor" "Bruce Wayne" "Clark Kent" "Peter Parker" "Diana Prince")
        sample_emails=("john@example.com" "jane@example.com" "alex@example.com" "emma@example.com" "david@example.com" "sarah@example.com" "bruce@example.com" "clark@example.com" "peter@example.com" "diana@example.com")

        for ((i=0; i<num_students; i++)); do
            idx=$((i % 10))
            if [ $i -ge 10 ]; then
                echo "${i}_${sample_emails[$idx]},${sample_names[$idx]} $i,0,0" >> "$TARGET_DIR/Helpers/assets.csv"
            else
                echo "${sample_emails[$idx]},${sample_names[$idx]},0,0" >> "$TARGET_DIR/Helpers/assets.csv"
            fi
        done
        echo "[INFO] Generated a brand new roster with $num_students entries."

 
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$TARGET_DIR/Helpers/config.json"
    else
        echo "[ERROR] Invalid choice. Aborting deployment."
        rm -rf "$TARGET_DIR"
        exit 1
    fi# 4. Enforce strict administrative system permissions
    chmod +x "$TARGET_DIR/attendance_checker.py"
    chmod 600 "$TARGET_DIR/Helpers/config.json"
    echo "[CONFIRM] Permissions set: App executable (+x), config locked to owner (600)."

    read -p "Would you like to customize the attendance alert thresholds? (y/n): " change_cfg
    if [[ "$change_cfg" =~ ^[Yy]$ ]]; then
        read -p "Enter warning percentage value (default 75): " user_warn
        read -p "Enter failure percentage value (default 50): " user_fail

        warn_val=${user_warn:-75}
        fail_val=${user_fail:-50}

        sed -i 's/"warning": [0-9]*/"warning": '"$warn_val"'/' "$TARGET_DIR/Helpers/config.json"
        sed -i 's/"failure": [0-9]*/"failure": '"$fail_val"'/' "$TARGET_DIR/Helpers/config.json"
        echo "[INFO] Attendance warning thresholds successfully synchronized"
     	echo "[VERIFY] Deploy complete! Handing over control to the program launcher..."
    is_deploying=false
    run_application "$proj_input"
    # ==============================================================================
# Feature 2: Run the Application
# ==============================================================================
run_application() {
    # Check if a project name was automatically passed from the Deploy feature
    local proj_input="$1"

    # If no project name was passed (meaning the user typed './deploy_agent.sh run' directly),
    # ask them which deployment workspace they want to launch
    if [ -z "$proj_input" ]; then
        echo "=== Feature 2: Run Active Project Workspace ==="
        read -p "Enter the project identifier suffix to execute: " proj_input
    fi

    # Establish the full targeted directory name path
    local target_run_dir="attendance_tracker_${proj_input}"

    # Guard clause: Fail early if the user types a workspace folder that doesn't exist
    if [ ! -d "$target_run_dir" ] || [ ! -f "$target_run_dir/attendance_checker.py" ]; then
        echo "[ERROR] Targeted directory workspace path '$target_run_dir' could not be found."
        exit 1
    fi

    # Navigate inside the deployment folder behind the scenes
    cd "$target_run_dir" || exit 1

    echo "[RUN] Handing interface control directly to Instructor session..."

    # Run the interactive python project tool directly in the console
    python3 attendance_checker.py

    # Move back out to the parent root directory once the Python program exits
    cd ..
}
# ==============================================================================
# Feature 3: Archive Log Files
# ==============================================================================
archive_logs() {
    echo "=== Feature 3: Archiving System Evaluation Log Files ==="
    read -p "Enter the project identifier target directory to archive logs for: " proj_input
    local target_run_dir="attendance_tracker_${proj_input}"

    # Guard clause: Verify the target workspace folder actually exists
    if [ ! -d "$target_run_dir" ]; then
        echo "[ERROR] Workspace folder target directory location '$target_run_dir' does not exist."
        exit 1
    fi

    # Generate an exact timestamp (YYYYMMDD_HHMMSS format)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archived_any=false

    # Check and move the attendance runtime session tracking log
    if [ -f "$target_run_dir/reports/attendance.log" ]; then
        local dest_attendance="$target_run_dir/archives/attendance/attendance_${timestamp}.log"
        mv "$target_run_dir/reports/attendance.log" "$dest_attendance"
        echo "[ARCHIVE SUCCESS] Log moved to: $dest_attendance"
        archived_any=true
    else
        echo "[INFO] No file found at reports/attendance.log to archive."
    fi

    # Check and move the absence evaluation summary tracking log
    if [ -f "$target_run_dir/reports/absent.log" ]; then
        local dest_absent="$target_run_dir/archives/absent/absent_${timestamp}.log"
        mv "$target_run_dir/reports/absent.log" "$dest_absent"
        echo "[ARCHIVE SUCCESS] Log moved to: $dest_absent"
        archived_any=true
    else
        echo "[INFO] No file found at reports/absent.log to archive."
    fi

    if [ "$archived_any" = true ]; then
        echo "[SUCCESS] Log file processing sequence finished safely."
    else
        echo "[SUCCESS] Checked reports/ directory cleanly. No runtime records were generated by app run."
    fi
}
