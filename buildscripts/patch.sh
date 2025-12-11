#!/bin/bash
set -euo pipefail  # 更严格的错误处理，同时捕获未定义变量

PATCHES=(patches/*)
ROOT=$(pwd)
echo "🔴 ROOT DIR: $ROOT"
echo "🔴 PATCHES LIST: ${PATCHES[*]}"
echo "----------------------------------------"

for dep_path in "${PATCHES[@]}"; do
    # 仅处理目录（如 patches/ffmpeg）
    if [ -d "$dep_path" ]; then
        patches=($dep_path/*)
        dep=$(basename "$dep_path")  # 更可靠的目录名提取（替代cut）
        dep_full_path="$ROOT/deps/$dep"
        
        echo "🟡 Processing dependency: $dep (path: $dep_full_path)"
        
        # 校验依赖目录是否存在
        if [ ! -d "$dep_full_path" ]; then
            echo "❌ ERROR: Dep directory $dep_full_path does NOT exist!"
            exit 1
        fi
        
        cd "$dep_full_path"
        echo "🟡 Current working dir: $(pwd)"
        echo "🟡 Resetting $dep to HEAD..."
        git reset --hard || { echo "❌ git reset failed for $dep"; exit 1; }

        # 专门处理FFmpeg，强制输出dashdec.c（含路径校验）
        if [[ "$dep" == "ffmpeg" ]]; then
            DASH_FILE="libavformat/dashdec.c"
            DASH_FULL_PATH="$dep_full_path/$DASH_FILE"
            
            echo "----------------------------------------"
            echo "🔍 Checking FFmpeg dashdec.c:"
            echo "   - Relative path: $DASH_FILE"
            echo "   - Full path: $DASH_FULL_PATH"
            
            if [ -f "$DASH_FILE" ]; then
                echo "✅ File exists! Printing full content:"
                echo "========================================"
                cat "$DASH_FILE" || { echo "❌ Failed to cat $DASH_FILE"; exit 1; }
                echo "========================================"
                echo "✅ End of $DASH_FILE (lines count: $(wc -l < "$DASH_FILE"))"
            else
                echo "❌ ERROR: $DASH_FILE does NOT exist in $(pwd)!"
                echo "   📂 Files in libavformat/: $(ls -l libavformat/ | grep -E "dash|dec" || echo "No dash files")"
                exit 1
            fi
            echo ""
        fi

        # 应用补丁逻辑
        for patch in "${patches[@]}"; do
            if [ ! -f "$patch" ]; then
                echo "⚠️ Skip non-file patch: $patch"
                continue
            fi
            
            echo "----------------------------------------"
            echo "🟡 Applying patch: $patch"

            # 输出补丁涉及的文件及当前hash
            files_in_patch=$(grep "^diff --git a/" "$patch" 2>/dev/null | sed 's|diff --git a/||; s| b/.*||')
            if [ -n "$files_in_patch" ]; then
                for file in $files_in_patch; do
                    if [ -f "$file" ]; then
                        current_hash=$(git ls-tree HEAD "$file" | awk '{print $3}')
                        echo "   📄 File: $file | Current blob hash: $current_hash"
                    else
                        echo "   ⚠️ File $file (from patch) does NOT exist in $dep!"
                    fi
                done
            fi

            # 尝试应用补丁（带详细输出）
            echo "   🚀 Running: git apply --verbose \"$patch\""
            if ! git apply --verbose "$patch"; then
                echo "❌ FAILED to apply patch $patch!"
                # 输出补丁冲突详情（关键调试）
                git apply --verbose --reject "$patch" || true
                echo "📜 Reject file (if any): $(ls -l *.rej 2>/dev/null || echo "None")"
                exit 1
            fi
            echo "✅ Patch applied successfully!"
            echo ""
        done

        cd "$ROOT"
        echo "🟡 Back to root dir: $ROOT"
        echo ""
    fi
done

echo "🎉 All patches applied successfully!"
exit 0
