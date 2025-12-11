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

        for patch in "${patches[@]}"; do
            echo "----------------------------------------"
            echo "Applying: $patch"

            # 提取 patch 中所有被修改的文件路径（a/xxx -> xxx）
            files_in_patch=$(grep "^diff --git a/" "$ROOT/$patch" | sed 's|diff --git a/||; s| b/.*||')

            if [ -n "$files_in_patch" ]; then
                echo "Files to be patched:"
                for file in $files_in_patch; do
                    if [ -f "$file" ]; then
                        current_hash=$(git ls-tree HEAD "$file" | awk '{print $3}')
                        echo "  $file --> current blob hash: $current_hash"
                    else
                        echo "  $file --> NOT FOUND (will likely fail)"
                    fi
                done
            fi

            echo "Running: git apply \"$ROOT/$patch\""
            git apply "$ROOT/$patch"
            echo "✅ Applied successfully"
            echo ""
        done

        cd "$ROOT"
    fi
done

exit 0
