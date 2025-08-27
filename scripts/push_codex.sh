#!/usr/bin/env zsh
set -euo pipefail
FILE="${FILE:-$HOME/PROMPT_CodexGPT_BFL.txt}"
[ -s "$FILE" ] || { echo "⛔ Prompt file not found or empty: $FILE"; exit 2; }
pbcopy < "$FILE"
URL="${URL:-https://chat.openai.com/}"
# попытаться открыть в Chrome, если нет — в Safari, иначе системный браузер
open -a "Google Chrome" "$URL" 2>/dev/null || open -a "Safari" "$URL" 2>/dev/null || open "$URL"
echo "📋 Prompt скопирован в буфер. Открыл чат. Вставь в поле ввода: Cmd+V"
