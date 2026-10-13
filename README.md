how to run the script and select a feature, how the threshold update works, how the log archiv (directories + timestamped filenames), how to test the Ctrl+C/Ctrl+Z path and what the .zip archive contains, and how you tested the deployed application structure.

DEPLOY AGENT

Shell script to deploy, run and archive logs for the Student Attendance Tracker.
 
REPOSITORY
deploy_agent_Nderitu11
-deploy_agent.sh
-README.md
-templates/
          -attendance_checker.py
          -assets.csv              
          -config.json          
   
RUNNING AND SELECTING A FEATURE
There are three features to deploy, to run and to archive .
so bash:
chmod +x deploy_agent.sh - to give permissions
./deploy_agent.sh        -provides an interactive menu with the options:1 Deploy, 2 Run, 3 Archive 4.Exit
If you want to jump to the featues bash with the specification using the following command
./deploy_agent.sh --deploy    
./deploy_agent.sh --run
./deploy_agent.sh --archive

DEPLOY
1.Pre-flight: checks python3 and zip exist, prints python3 --version, and confirms the templates are readable.
2.Name: asks for a name (characters should only be letters, digits, _, - only) and creates attendance_tracker_<name>/ with attendance_checker.py, assets.csv,config.json. If the directory exists you are asked to overwrite or abort. 
3.Roster: Option A copies N rows (+ header) from templates/assets.csv; Option B generates N students from built-in name/email arrays with counts at 0.
4.total_sessions: Option A -> 5 (4 prior sessions + today); Option B -> 1 (first session). Set with sed.
5.Permissions: chmod +x attendance_checker.py, chmod 600 Helpers/config.json, confirmed with ls -l.
6.Thresholds: optional. Input must be whole numbers 0-100 and failure < warning; invalid input re-prompts before sed runs. Only the "warning" and "failure" lines are edited in place.
7.Verify: launches the app (Feature 2).

RUN

Runs python3 attendance_checker.py from inside the chosen project directory.

ARCHIVE

Each existing log in reports/ is moved to its own archive directory with a timestamp (YYYYMMDD_HHMMSS):

archives/attendance/attendance_20261011_143022.log
archives/absent/absent_20261011_143022.log

A missing log (e.g. no absences -> no absent.log) is reported and skipped; the script does not crash. Moving (not copying) keeps reports/ clean for the next session.

SIGNALS (archive trigger)

During deployment, SIGINT (Ctrl+C) and SIGTSTP (Ctrl+Z) are trapped. The handler:

1.prints that deployment was interrupted,
2.runs zip -r attendance_tracker_<name>_archive.zip attendance_tracker_<name> (whatever exists so far),
3.deletes the incomplete directory (only if the zip succeeded),
4.exits cleanly.

The trap is removed once deployment finishes, so it never affects attendance_checker.py marking sessions.

Test it: run ./deploy_agent.sh --deploy, enter a name, and press Ctrl+C or Ctrl+Z at any prompt. Then unzip -l attendance_tracker_<name>_archive.zip to see the partial contents and ls to confirm the directory is gone.

TESTING THE DEPLOYED STRUCTURE
bash
find attendance_tracker_name | sort
ls -l attendance_tracker_<name>/attendance_checker.py attendance_tracker_<name>/Helpers/config.json
cat attendance_tracker_<name>/Helpers/config.json

The built-in verification step (running the app) proves the structure, roster and config work together.
