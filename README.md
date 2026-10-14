DEPLOY AGENT

# Automated Project Bootstrapping & Process Management

The Python Student Attendance Tracker application is automated by a bash script for deployment and management in this project.

The script is called 'deploy_agent.sh' It provides three main features:

1. Deploy the application.
2. Run the application.
3. Archive attendance log files.

It also carries out pre-flight checks, sets file permissions, lets users change attendance thresholds, and accommodates deployment interruptions due to Ctrl+ C or Ctrl+ Z.

REPOSITORY STRUCTURE

deploy_agent_GithubUsername/
   -deploy_agent.sh
   -README.md
   -templates/
             -attendance_checker.py
             -assets.csv
             -config.json

Replace `GithubUsername` with your actual GitHub username.

The `templates/` folder contains the original application files. The Python application is copied without modification.

REQUIRED TOOLS

The following tools must be installed:

- Bash
- Python 3
- ZIP

The script also requires the three template files listed above.
 
RUNNING THE SCRIPT

Open a terminal in the repository directory and run:
bash
chmod +x deploy_agent.sh
./deploy_agent.sh

The script displays an interactive menu with option and menu:
1.Deploy the application 
2.Run an existing project
3.Archive log files 
4.Exit 

Feature 1:DEPLOY
To deploy the Application, perform the following steps:

The feature deploymentchecks if Python3 and ZIP are installed and looks for required templates.
A project name is entered by the user. If you don't have a project with the same name, the script will ask you if you want to overwrite it, and will create a new directory called attendance_tracker_"name" if you do.
The application and configuration files are copied from "templates/".

Roster Options

Option A- Copy the template roster.

To make a copy of the template roster, select Option A.Select Option A — Copy the template roster.

How many students to copy is decided by the user of the program in the file `templates/assets.csv`. The header is added and the total_sessions is set to 5 to reflect the four previous sessions.

Option B — Generate a fresh roster
The script creates student records from two arrays (names and email prefixes). The number of sessions is always zero when it starts and `total_sessions=1`.

Permissions

The following permissions are applied in the script:

- attendance_checker.py: executable.
- Helpers/config.json: owner read/write only,`chmod 600`.

Attendance thresholds

The user can set the level of the warnings and the failure limit.
The default setting values are 75% for warning and 50% for the failure. Input should be numbers, within range 0 to 100, and the failure threshold should be less than the warning threshold.
The 'sed' command is used to modify the values in the deployed configuration file.
The script is then run after deployment to test the application.

Feature 2: RUN THE APPLICATION
The run feature lets the user choose from a list of previously deployed projects.

Switchs to the project directory and runs the script:

bash
python3 attendance_checker.py

The application prompts the instructor to mark students as present or absent. It updates the roster and creates attendance logs in the reports/ directory.

Feature 3:ARCHIVE LOGS

The archive feature checks for the following files:

- reports/attendance.log
- reports/absent.log

Each existing log is moved into its own archive directory. A timestamp is added to the filename to distinguish archived copies.

The resulting structure is:
archives/
  -attendance/
     -attendance_YYYYMMDD_HHMMSS.log
  -absent/
      -absent_YYYYMMDD_HHMMSS.log
If a log does not exist, the script reports that it was skipped and continues processing the other log.

SIGNAL HANDLING DEPLOYMENT

During deployment, the script installs a signal trap for:

- SIGINT, usually triggered by Ctrl+C.
- SIGTSTP, usually triggered by Ctrl+Z.

When either signal is received during deployment, the script attempts to create a ZIP archive named:

attendance_tracker_<name>_archive.zip

The archive is the original project directory (not fully complete) at the point of interruption.

The incomplete project directory is removed from the workspace to avoid clutter if the ZIP archive is created. In the event of an archive failure, the directory is retained so that no files are lost.

The signal trap is removed when deployment finishes successfully.

How to test signal handling

1. Start the script and choose deployment.
2. Enter a project name.
3. Interrupt the deployment while it is in progress.
4. Check whether the ZIP archive was created.
5. Confirm that the incomplete project directory was removed only after successful archiving.
It's important to interrupt at the right time, so give it a test run and make sure that the resulting files are correct.

TESTING

- Confirm that Python 3 and ZIP are detected.
- Test deployment using both roster options.
- Confirm that the correct directory structure and configuration values are created.
- Enter invalid threshold values and confirm that they are rejected.
- Verify file permissions using ls 
- Run the application and complete a sample attendance session.
- Archive the logs and verify their destinations and timestamped names.
- Test missing log files and existing project directories.
- Test Ctrl+C and Ctrl+Z during deployment.
- Confirm that interrupted deployment creates a ZIP archive and cleans up the incomplete directory when archiving succeeds.

VIDEO DEMONSTRATION

Video link: https://drive.google.com/file/d/1Gjl8LCJnTEprKyFlwEQHo2kjCXFnlX-l/view?usp=sharing
