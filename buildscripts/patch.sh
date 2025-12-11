#!/bin/bash -e

PATCHES=(patches/*)
ROOT=$(pwd)

for dep_path in "${PATCHES[@]}"; do
    if [ -d "$dep_path" ]; then
        patches=($dep_path/*)
        dep=$(echo "$dep_path" | cut -d/ -f 2)
        cd "deps/$dep"
        echo "Patching $dep"
        git reset --hard

        # 如果是 ffmpeg，且 dashdec.c 存在，完整输出其内容
        if [[ "$dep" == "ffmpeg" ]]; then
            DASH_FILE="libavformat/dashdec.c"
            if [ -f "$DASH_FILE" ]; then
                echo "========================================"
                echo "📄 FULL SOURCE OF $DASH_FILE (for debugging):"
                echo "========================================"
                cat "$DASH_FILE"
                echo "========================================"
                echo "✅ End of $DASH_FILE"
                echo ""
            fi
        fi

        for patch in "${patches[@]}"; do
            echo "----------------------------------------"
            echo "Applying: $patch"

            # 输出 hash（可选）
            files_in_patch=$(grep "^diff --git a/" "$ROOT/$patch" 2>/dev/null | sed 's|diff --git a/||; s| b/.*||')
            if [ -n "$files_in_patch" ]; then
                for file in $files_in_patch; do
                    if [ -f "$file" ]; then
                        current_hash=$(git ls-tree HEAD "$file" | awk '{print $3}')
                        echo "File: $file --> blob hash: $current_hash"
                    fi
                done
            fi

            echo "Running: git apply \"$ROOT/$patch\""
            if ! git apply "$ROOT/$patch"; then
                echo "❌ FAILED to apply patch."
                exit 1
            fi
            echo "✅ Applied successfully"
            echo ""
        done

        cd "$ROOT"
    fi
done

exit 0
