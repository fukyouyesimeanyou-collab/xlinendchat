#!/usr/bin/env bash
#
# scripts/update_changes_log.sh "Commit Message"
# 自動提取 Git 變動並格式化為 Markdown 表格追加至 changes.log
#

set -euo pipefail

LOG_FILE="changes.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
COMMIT_MSG="${1:-🔄 無說明 / No description}"

# 偵測變動檔案 (Detect changed files)
# 我們優先看已暫存 (staged) 的變動，這樣可以包含在當次 commit
CHANGES=$(git diff --cached --name-status)

if [ -z "$CHANGES" ]; then
    # 如果暫存區是空的，嘗試看最後一次 commit (用於 post-commit hook)
    CHANGES=$(git show --pretty="" --name-status HEAD 2>/dev/null || true)
fi

if [ -z "$CHANGES" ]; then
    exit 0
fi

# 格式化並追加寫入 (Format and append)
echo "$CHANGES" | while read -r status file; do
    # 略過 changes.log 本身，避免無限遞迴
    if [ "$file" == "$LOG_FILE" ]; then continue; fi

    # 狀態轉換 (Status translation)
    case "$status" in
        A) STATUS_STR="Added / 已新增" ;;
        M) STATUS_STR="Modified / 已修改" ;;
        D) STATUS_STR="Deleted / 已刪除" ;;
        R*) STATUS_STR="Renamed / 已重命名" ;;
        *) STATUS_STR="Changed / 變更" ;;
    esac

    # 寫入表格列 (Append Markdown row)
    # 格式: | Timestamp | File | Change Description |
    echo "| $TIMESTAMP | \`$file\` | **$STATUS_STR**: $COMMIT_MSG |" >> "$LOG_FILE"
done
