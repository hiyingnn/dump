#!/bin/bash

# Configuration
REPORT_DIR="dependency-reports"
INPUT_FILE="unique_deps.tmp"
TRANSITIVE=false

# 1. Handle Flags
while getopts "t" opt; do
  case $opt in
    t)
      TRANSITIVE=true
      ;;
    \?)
      echo "Usage: ./report.sh [-t (for transitive)]"
      exit 1
      ;;
  esac
done

echo "--- Initializing Clean Run ---"

# 2. Cleanup old data
[ -d "$REPORT_DIR" ] && rm -rf "$REPORT_DIR"
[ -f "$INPUT_FILE" ] && rm "$INPUT_FILE"
mkdir -p "$REPORT_DIR"

# Optional: Maven clean to ensure project state is fresh
echo "Running 'mvn clean' to refresh project state..."
mvn clean -q

# 3. Extract Dependencies
if [ "$TRANSITIVE" = true ]; then
    echo "Mode: ALL Dependencies (Transitive)"
    EXTRACT_FLAG=""
else
    echo "Mode: DECLARED Dependencies Only (Top-level)"
    EXTRACT_FLAG="-DexcludeTransitive=true"
fi

echo "Step 1: Extracting unique dependencies..."
mvn dependency:list $EXTRACT_FLAG 2>&1 | \
    sed -nE 's/.* ([^:]+:[^:]+):[a-z]+:[^: ]+.*/\1/p' | \
    grep -v "dependencies.dependency" | \
    sort -u > "$INPUT_FILE"

# Check if list generation worked
if [ ! -s "$INPUT_FILE" ]; then
    echo "Error: No dependencies found."
    exit 1
fi

COUNT=$(wc -l < "$INPUT_FILE")
echo "Found $COUNT unique dependencies. Generating reports..."

# 4. Loop and Generate Trees
while read -r dep || [ -n "$dep" ]; do
    [ -z "$dep" ] && continue

    safe_name=$(echo "$dep" | tr ':' '-')
    report_path="$(pwd)/$REPORT_DIR/${safe_name}-all-dependencies.txt"

    echo "Processing: $dep"

    # We use tree with the specific include
    # Even if we only listed declared deps, the tree shows the hierarchy
    mvn dependency:tree -Dincludes="$dep" \
        -DoutputFile="$report_path" \
        -DappendOutput=true \
        -q

done < "$INPUT_FILE"

# 5. Final Cleanup
rm "$INPUT_FILE"

echo "------------------------------------------------"
echo "Success! Reports generated in /$REPORT_DIR"
echo "Mode used: $( [ "$TRANSITIVE" = true ] && echo 'Transitive' || echo 'Top-level Only' )"