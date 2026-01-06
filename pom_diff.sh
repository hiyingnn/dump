#!/bin/bash

echo "🚀 Starting POM & Dependency Audit..."

MODULE_DIRS=(
    "ima-services/authentication-ms"
    "ima-services/consumer-ms"
    "ima-services/device-ms"
    "ima-services/metric-ms"
    "ima-services/notification-ms"
    "ima-services/product-expiry-ms"
    "ima-services/product-ms"
    "ima-services/telemetry-ms"
    "ima-services/whitelist-ms"
     "ima-services/device-ms"
)

ROOT_DIR=$(pwd)

for REL_DIR in "${MODULE_DIRS[@]}"; do
    ABS_DIR="$ROOT_DIR/$REL_DIR"

    if [ ! -d "$ABS_DIR" ]; then
        echo "⚠️  Directory $ABS_DIR not found, skipping..."
        continue
    fi

    SERVICE_NAME=$(basename "$ABS_DIR")
    echo "----------------------------------------------------------"
    echo "📂 Module: $SERVICE_NAME"

    REPORT_SUBDIR="$ABS_DIR/pom-diff"
    mkdir -p "$REPORT_SUBDIR"

    # Define paths for Effective POM and Dependency Tree
    EFF_OLD="$ABS_DIR/effective-old.xml"
    EFF_NEW="$ABS_DIR/effective-new.xml"
    TREE_OLD="$ABS_DIR/tree-old.txt"
    TREE_NEW="$ABS_DIR/tree-new.txt"

    # --- 1. GENERATE EFFECTIVE POMS ---
    echo "   > Generating Effective XMLs..."
    mvn help:effective-pom -f "$ABS_DIR/pom-old.xml" -Doutput="$EFF_OLD" -q
    mvn help:effective-pom -f "$ABS_DIR/pom.xml" -Doutput="$EFF_NEW" -q

    # --- 2. GENERATE SORTED DEPENDENCY TREES ---
    echo "   > Generating Deterministic Dependency Trees..."
    mvn dependency:tree -f "$ABS_DIR/pom-old.xml" -Dtokens=whitespace > "$TREE_OLD"
    mvn dependency:tree -f "$ABS_DIR/pom.xml"  -Dtokens=whitespace > "$TREE_NEW"

    # --- 3. EXECUTE DIFFS ---
    echo "   > Running Diffs..."

    # POM Diff
    git diff --no-index "$EFF_OLD" "$EFF_NEW" > "$REPORT_SUBDIR/${SERVICE_NAME}-pom.diff"

    # Dependency Tree Diff
    git diff --no-index "$TREE_OLD" "$TREE_NEW" > "$REPORT_SUBDIR/${SERVICE_NAME}-tree.diff"

    # --- 4. CLEANUP & ORGANIZE ---
    mv "$EFF_OLD" "$EFF_NEW" "$TREE_OLD" "$TREE_NEW" "$REPORT_SUBDIR/"

    echo "   ✅ Reports saved to: $REPORT_SUBDIR"
done

echo "----------------------------------------------------------"
echo "✅ Done!"