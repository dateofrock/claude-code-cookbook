#!/bin/bash
set -euo pipefail

# 日本語と半角英数字の間に半角スペースを挿入
if [ -n "${1:-}" ]; then
  file_path="$1"
else
  file_path=$(jq -r '.tool_input.file_path // empty' <<<"${CLAUDE_TOOL_INPUT:-$(cat)}")
fi

[ -z "$file_path" ] || [ ! -f "$file_path" ] || [ ! -r "$file_path" ] || [ ! -w "$file_path" ] && exit 0

EXCLUSIONS_FILE="$(dirname "${BASH_SOURCE[0]}")/ja-space-exclusions.json"

temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Perlで正規表現範囲を安定的に
perl -CSDA -pe '
  s/([\p{Hiragana}\p{Katakana}\p{Han}])([a-zA-Z0-9])/$1 $2/g;
  s/([a-zA-Z0-9])([\p{Hiragana}\p{Katakana}\p{Han}])/$1 $2/g;
' "$file_path" > "$temp_file"

# 除外リスト適用：ここは要変換
if [ -f "$EXCLUSIONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    # エスケープ（perl用に変換の例）
    perl -CSDA -pi -e "s/\Q$(echo $pattern)\E/$pattern/g" "$temp_file"
  done < <(jq -r '.exclusions[]' "$EXCLUSIONS_FILE" 2>/dev/null)
fi

mv "$temp_file" "$file_path"
