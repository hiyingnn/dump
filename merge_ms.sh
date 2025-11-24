#!/bin/bash

# --- Configuration ---
MONOREPO_ROOT="monorepo"
MONOREPO_URL="git-monorepo-link.git"

# --- Function to Merge a Single Microservice ---
merge_microservice() {
    
    local MS_NAME="$1"
    local MS_URL="$2"
    local TEMP_DIR="${MS_NAME}-temp"
    local SUBDIRECTORY="xx-projects/${MS_NAME}"
    
    # Define absolute paths based on the script's entry point (the parent directory)
    local PARENT_PATH="$(pwd)"
    local MONOREPO_PATH="${PARENT_PATH}/${MONOREPO_ROOT}"

    echo "==========================================================="
    echo "🚀 Starting merge for: ${MS_NAME}"
    echo "-----------------------------------------------------------"

    # --- 1. Filter History (Must run from PARENT_PATH) ---
    echo "1. Cloning and filtering history..."
    cd "${PARENT_PATH}" # Ensure we are in the parent directory
    
    git clone --mirror "${MS_URL}" "${TEMP_DIR}"
    
    cd "${TEMP_DIR}" || { echo "ERROR: Cannot enter temporary directory ${TEMP_DIR}"; exit 1; }
    git filter-repo --to-subdirectory-filter "${SUBDIRECTORY}"
    cd "${PARENT_PATH}" # Return to parent directory

    # --- 2. Setup Remote and Fetch (Must run from MONOREPO_PATH) ---
    echo "2. Fetching filtered history..."
    
    cd "${MONOREPO_PATH}" || { echo "ERROR: Failed to enter monorepo directory ${MONOREPO_PATH}"; exit 1; }
    
    git remote add "${TEMP_DIR}" "${PARENT_PATH}/${TEMP_DIR}"
    git fetch "${TEMP_DIR}"

    # --- 3. Merge Branches (DEV FIRST) ---
    
    # CRITICAL: Flag required for the first merge into the monorepo's integration branch (DEV)
    local UNRELATED_FLAG="--allow-unrelated-histories" 
    
    # --- A. Merge DEV (The Integration Base) ---
    echo "   -> Merging ${MS_NAME}/dev (BASE)..."
    if ! git show-ref --verify --quiet "refs/heads/dev"; then
        # Create dev if it doesn't exist (only on the first microservice)
        git checkout main # Start from main's initial commit
        git checkout -b dev 
    fi
    git checkout dev 
    
    # Use the UNRELATED_FLAG for the DEV branch merge
    git merge "${TEMP_DIR}/dev" ${UNRELATED_FLAG} -m "Merge ${MS_NAME}/dev into monorepo [Integration Base]"
    git branch -M dev
    git push -u origin dev

    # --- B. Update MAIN Branch ---
    echo "   -> Merging ${MS_NAME}/main..."
    if ! git show-ref --verify --quiet "refs/heads/main"; then
        git checkout -b main
    fi
    git checkout main 

    # First, bring in the new microservice history from the updated 'dev' branch
    git merge dev -m "Propagate ${MS_NAME} history from dev to main"
    
    # Then, merge the microservice's specific main branch history (no UNRELATED_FLAG needed here)
    git merge "${TEMP_DIR}/main" -m "Merge ${MS_NAME}/main specific history"
    git branch -M main
    git push -u origin main

    # --- C. Update STAGING Branch ---
    echo "   -> Merging ${MS_NAME}/staging..."
    if ! git show-ref --verify --quiet "refs/heads/staging"; then
        git checkout main # Base new branch creation off main
        git checkout -b staging
    fi
    git checkout staging
    
    # Propagate the primary changes from 'main'
    git merge main -m "Propagate ${MS_NAME} history from main to staging"
    
    # Then, merge the specific staging history
    git merge "${TEMP_DIR}/staging" -m "Merge ${MS_NAME}/staging specific history"
    git branch -M staging
    git push -u origin staging

    # --- D. Update DEMO Branch ---
    echo "   -> Merging ${MS_NAME}/demo..."
    if ! git show-ref --verify --quiet "refs/heads/demo"; then
        git checkout main # Base new branch creation off main
        git checkout -b demo
    fi
    git checkout demo
    
    git merge main -m "Propagate ${MS_NAME} history from main to demo"
    git merge "${TEMP_DIR}/demo" -m "Merge ${MS_NAME}/demo specific history"
    git branch -M demo
    git push -u origin demo
    
    # --- 4. Clean Up (Run from MONOREPO_PATH) ---
    echo "4. Cleaning up temporary remote and directory..."
    git remote remove "${TEMP_DIR}"
    
    cd "${PARENT_PATH}" 
    rm -rf "${TEMP_DIR}"
    
    echo "-----------------------------------------------------------"
    echo "✅ ${MS_NAME} merge complete."
    echo "==========================================================="
}

# -----------------------------------------------------------------------
# EXECUTION
# -----------------------------------------------------------------------

PARENT_DIR_FOR_SCRIPT="$(pwd)"
cd "${PARENT_DIR_FOR_SCRIPT}" || exit

# --- 1. Initialize Monorepo (Run once outside the function) ---
if [ ! -d "${MONOREPO_ROOT}" ]; then
    echo "--- INITIALIZING NEW MONOREPO ---"
    
    mkdir "${MONOREPO_ROOT}"
    cd "${MONOREPO_ROOT}"
    git init
    git commit --allow-empty -m "initialize monorepo"
    
    # Create main branch and setup remote
    git branch -M main
    git remote add origin "${MONOREPO_URL}"
    git push -u origin main 
    
    # CRITICAL: Create the 'dev' branch based on 'main' before any merge
    git checkout -b dev
    git push -u origin dev
    
    # Create other branches for completeness
    git checkout main
    git checkout -b staging
    git push -u origin staging
    
    git checkout main
    git checkout -b demo
    git push -u origin demo
    
    cd .. # Return to PARENT_DIR_FOR_SCRIPT
fi

# --- 2. Execute Merges ---
# IMPORTANT: Ensure you start with a clean monorepo (delete previous failed runs).
merge_microservice "xx-ms" "git-ms-repo-url"

echo "--- ALL MERGES COMPLETE ---"
