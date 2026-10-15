  #!/bin/bash

# Function to catch Ctrl+C and Ctrl+Z
# I had trouble with this at first but it works now
cleanup_on_interrupt() {
    echo -e "\n[!] Deploiement stopped by user !"
    if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
        echo "[*] Zipping the incomplete folder..."
        zip -r "${TARGET_DIR}_archive.zip" "$TARGET_DIR" > /dev/null 2>&1
        rm -rf "$TARGET_DIR"
        echo "[*] Folder zipped and cleaned up."
    fi
    exit 130
}
# Feature 1: Deploy
deploy_app() {
    trap cleanup_on_interrupt SIGINT SIGTSTP

    # 1. Check if tools are there
    if ! command -v python3 &> /dev/null; then
        echo "ERROR: python3 not found."
        trap - SIGINT SIGTSTP
        return
    fi
    if ! command -v zip &> /dev/null; then
        echo "ERROR: zip not found."
        trap - SIGINT SIGTSTP
        return
    fi

    # 2. Ask for name
    read -p "Enter project suffix (ex: v1): " proj_suffix
    TARGET_DIR="attendance_tracker_${proj_suffix}"

    # Check if exists
    if [ -d "$TARGET_DIR" ]; then
        read -p "Folder $TARGET_DIR exists. Overwrite? (y/n): " overwrite
        if [ "$overwrite" != "y" ]; then
            echo "Deployment stopped."
            trap - SIGINT SIGTSTP
            return
        fi
        rm -rf "$TARGET_DIR"
    fi

    # 3. Create folders
    echo "DEBUG: creating folders..."
    mkdir -p "$TARGET_DIR/Helpers"
    mkdir -p "$TARGET_DIR/reports"
    mkdir -p "$TARGET_DIR/archives/attendance"
    mkdir -p "$TARGET_DIR/archives/absent"

    # 4. Copy files
    cp templates/attendance_checker.py "$TARGET_DIR/"
    cp templates/config.json "$TARGET_DIR/Helpers/"

    # 5. Ask about roster
    echo "Choose roster method:"
    echo "A) Copy from template"
    echo "B) Generate new"
    read -p "Choice (A/B): " roster_choice

    # I had a bug here with the uppercase letters, fixed it now
    if [ "$roster_choice" == "A" ] || [ "$roster_choice" == "a" ]; then
        read -p "How many students to copy? (Max 10): " stud_number
        head -n $((stud_number + 1)) templates/assets.csv > "$TARGET_DIR/Helpers/assets.csv"
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 5/' "$TARGET_DIR/Helpers/config.json"
    elif [ "$roster_choice" == "B" ] || [ "$roster_choice" == "b" ]; then
        read -p "How many students? " stud_number
        echo "Email,Names,Attendance Count,Absence Count" > "$TARGET_DIR/Helpers/assets.csv"
        for ((i=1; i<=stud_number; i++)); do
            echo "student${i}@example.com,Student ${i},0,0" >> "$TARGET_DIR/Helpers/assets.csv"
        done
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$TARGET_DIR/Helpers/config.json"
    else
        echo "Invalid choice. Stopping."
        rm -rf "$TARGET_DIR"
        trap - SIGINT SIGTSTP
        return
    fi

    # 6. Permissions
    chmod +x "$TARGET_DIR/attendance_checker.py"
    chmod 600 "$TARGET_DIR/Helpers/config.json"
    echo "[+] Permissions set."
    
    # Small pause just to be sure
    sleep 1

    # 7. Update thresholds
    read -p "Update warning/failure thresholds? (y/n): " update_thresh
    if [ "$update_thresh" == "y" ]; then
        read -p "Warning threshold [default 75]: " warn_val
        warn_val=${warn_val:-75}
        read -p "Failure threshold [default 50]: " fail_val
        fail_val=${fail_val:-50}

        if [[ "$warn_val" =~ ^[0-9]+$ ]] && [[ "$fail_val" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"warning\": [0-9]*/\"warning\": $warn_val/" "$TARGET_DIR/Helpers/config.json"
            sed -i "s/\"failure\": [0-9]*/\"failure\": $fail_val/" "$TARGET_DIR/Helpers/config.json"
            echo "[+] Thresholds updated."
        else
            echo "[-] Invalid input. Keeping defaults."
        fi
    fi

    trap - SIGINT SIGTSTP

    # 8. Run verification
    echo "[+] Verifying deployment..."
    cd "$TARGET_DIR"
    python3 attendance_checker.py
    cd ..
}
