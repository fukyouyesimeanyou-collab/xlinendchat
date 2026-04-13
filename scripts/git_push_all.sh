#!/usr/bin/env bash
#
# git_push_all.sh
#
# 用途 (Usage):
#   ./scripts/git_push_all.sh "你的 commit 訊息"
#
# 效果 (Effect):
#   git add .  →  git commit  →  同時 push 到 GitHub / GitLab / Codeberg / SourceHut
#
# 注意 (Note):
#   SourceHut 若網路不可達，push 視為可選項（不會中斷其他平台）。

set -euo pipefail
export SKIP_LOG_HOOK=1

# ── 顏色輸出 (Color output) ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_fail()  { echo -e "${RED}[FAIL]${RESET}  $*"; }

# ── 若未提供 commit 訊息，自動用時間戳記 (Auto-timestamp if no message given) ──
COMMIT_MSG="${1:-🔄 backup $(date '+%Y-%m-%d %H:%M')}"

# ── 移至 repo 根目錄 (Navigate to repo root) ──
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  log_fail "找不到 git repo，請在專案目錄內執行此腳本。"
  exit 1
fi
cd "$REPO_ROOT"

# ── git add & commit ──
log_info "暫存所有變更 (Staging all changes)..."
git add .

if git diff --cached --quiet; then
  log_warn "沒有需要 commit 的變更 (Nothing to commit)，跳過 commit 步驟。"
else
  # ── 自動更新變更日誌 (Auto-update changes log) ──
  log_info "正在更新變更日誌 (Updating changes.log)..."
  bash scripts/update_changes_log.sh "$COMMIT_MSG"
  git add changes.log

  git commit -m "$COMMIT_MSG"
  log_ok "Commit 完成：'$COMMIT_MSG'"
fi

# ── 推送到所有平台 (Push to all remotes via 'all') ──
log_info "開始推送到所有雲端平台 (Pushing to all remotes)..."
echo ""

PUSH_FAILED=0

# 使用 all remote 一次推送（GitHub、GitLab、Codeberg 為主要目標）
if git push all main 2>&1; then
  log_ok "GitHub / GitLab / Codeberg 推送完成"
else
  # SourceHut 可能失敗，個別嘗試其他三個
  log_warn "all remote 部分失敗，改為逐一推送..."
  for remote in github gitlab codeberg; do
    if git push "$remote" main 2>&1; then
      log_ok "$remote 推送成功"
    else
      log_fail "$remote 推送失敗"
      PUSH_FAILED=1
    fi
  done

  # SourceHut 單獨嘗試（網路問題時為可選項）
  log_info "嘗試推送到 SourceHut (optional)..."
  if git push sourcehut main 2>&1; then
    log_ok "SourceHut 推送成功"
  else
    log_warn "SourceHut 推送失敗（網路問題，已略過）"
  fi
fi

echo ""
if [ "$PUSH_FAILED" -eq 0 ]; then
  log_ok "================================================================"
  log_ok " 備份完成！所有雲端平台已同步。"
  log_ok "================================================================"
else
  log_warn "部分平台推送失敗，請檢查上方錯誤訊息後重試。"
fi
