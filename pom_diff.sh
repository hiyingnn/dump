#!/bin/bash

echo "🚀 Starting POM Audit..."

# 1. Explicit list of directories
MODULE_DIRS=(
    "xxx"
)

# Get the absolute path of the root folder where you run this script
ROOT_DIR=$(pwd)

for REL_DIR in "${MODULE_DIRS[@]}"; do
    # Create the full absolute path to the module
    ABS_DIR="$ROOT_DIR/$REL_DIR"

    if [ ! -d "$ABS_DIR" ]; then
        echo "⚠️  Directory $ABS_DIR not found, skipping..."
        continue
    fi

    # Get the service name for filenames
    SERVICE_NAME=$(basename "$ABS_DIR")

    echo "----------------------------------------------------------"
    echo "📂 Module: $SERVICE_NAME"

    # 2. Define the report subdirectory
    REPORT_SUBDIR="$ABS_DIR/pom-diff"
    mkdir -p "$REPORT_SUBDIR"

    # 3. Define EXACT absolute paths for the XML files
    # This prevents the nested directory creation issue
    EFF_OLD="$ABS_DIR/effective-old.xml"
    EFF_NEW="$ABS_DIR/effective-new.xml"

    # 4. Generate Effective POMs
    echo "   > Generating Effective XMLs..."
    mvn help:effective-pom -f "$ABS_DIR/pom-old.xml" -Doutput="$EFF_OLD" -q
    mvn help:effective-pom -f "$ABS_DIR/pom.xml" -Doutput="$EFF_NEW" -q

    # 5. Clean XML noise
    # We use the absolute path variables here to ensure sed finds the right file
    sed -i '//d' "$EFF_OLD" "$EFF_NEW"

    # 6. Git Diff Command
    echo "   > Running Git Diff..."
    DIFF_FILE="$REPORT_SUBDIR/${SERVICE_NAME}.diff"
    git diff --no-index "$EFF_OLD" "$EFF_NEW" > "$DIFF_FILE"

    # 7. Move XMLs into the subdirectory
    mv "$EFF_OLD" "$REPORT_SUBDIR/effective-old.xml"
    mv "$EFF_NEW" "$REPORT_SUBDIR/effective-new.xml"

    echo "   ✅ Report saved to: $REPORT_SUBDIR"
done

echo "----------------------------------------------------------"
echo "✅ Done! All audits complete."