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
