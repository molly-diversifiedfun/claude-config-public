#!/bin/bash
# PostToolUse hook: validates n8n workflow JSON files on Write/Edit
# Enforces:
# 1. callback_data strings must be under 64 bytes (Telegram limit)
# 2. Workflows with inline_keyboard MUST have a companion callback handler
# 3. Workflows with telegramTrigger callback_query MUST have answerCallbackQuery

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run on Write/Edit to n8n-workflows/*.json
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

if [[ ! "$FILE_PATH" =~ n8n-workflows/.*\.json$ ]]; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

ERRORS=""

# Check 1: callback_data length (64-byte Telegram limit)
# Extract all callback_data values using grep -o (POSIX compatible)
LONG_CALLBACKS=$(grep -o '"callback_data"[[:space:]]*:[[:space:]]*"[^"]*"' "$FILE_PATH" 2>/dev/null | while read -r line; do
  DATA=$(echo "$line" | sed 's/.*"callback_data"[[:space:]]*:[[:space:]]*"//;s/"$//')
  BYTES=$(printf '%s' "$DATA" | wc -c | tr -d ' ')
  if [ "$BYTES" -gt 64 ]; then
    echo "FAIL: callback_data '$DATA' is $BYTES bytes (max 64)"
  fi
done)

if [[ -n "$LONG_CALLBACKS" ]]; then
  ERRORS="$ERRORS\n$LONG_CALLBACKS"
fi

# Check 2: inline_keyboard without answerCallbackQuery in same workflow set
HAS_INLINE_KB=$(grep -c "inline_keyboard" "$FILE_PATH" 2>/dev/null)
HAS_ANSWER_CB=$(grep -c "answerCallbackQuery" "$FILE_PATH" 2>/dev/null)

if [[ "$HAS_INLINE_KB" -gt 0 && "$HAS_ANSWER_CB" -eq 0 ]]; then
  # Check if a companion callback handler exists in same directory
  DIR=$(dirname "$FILE_PATH")
  COMPANION=$(grep -rl "answerCallbackQuery" "$DIR"/*.json 2>/dev/null | head -1)
  if [[ -z "$COMPANION" ]]; then
    ERRORS="$ERRORS\nWARN: Workflow sends inline_keyboard but no answerCallbackQuery found in this file or companion workflows in $DIR/. Telegram buttons will show a spinning indicator forever without answerCallbackQuery."
  fi
fi

# Check 3: telegramTrigger with callback_query MUST have answerCallbackQuery
HAS_CB_TRIGGER=$(grep -c '"callback_query"' "$FILE_PATH" 2>/dev/null)
if [[ "$HAS_CB_TRIGGER" -gt 0 && "$HAS_ANSWER_CB" -eq 0 ]]; then
  ERRORS="$ERRORS\nFAIL: Workflow has Telegram callback_query trigger but no answerCallbackQuery node. Buttons will spin forever."
fi

# Check 4: Code nodes using fetch() instead of this.helpers.httpRequest()
HAS_FETCH=$(grep -c '"fetch(' "$FILE_PATH" 2>/dev/null)
HAS_AWAIT_FETCH=$(grep -c 'await fetch(' "$FILE_PATH" 2>/dev/null)
if [[ "$HAS_FETCH" -gt 0 || "$HAS_AWAIT_FETCH" -gt 0 ]]; then
  ERRORS="$ERRORS\nFAIL: Code node uses fetch() which doesn't exist in n8n. Use this.helpers.httpRequest({ method, url, headers, body }) instead."
fi

# Check 5: HTTP Request nodes with authentication:"none" and manual apikey headers (should use credentials)
HAS_AUTH_NONE=$(grep -c '"authentication"[[:space:]]*:[[:space:]]*"none"' "$FILE_PATH" 2>/dev/null)
HAS_MANUAL_APIKEY=$(grep -c '"name"[[:space:]]*:[[:space:]]*"apikey"' "$FILE_PATH" 2>/dev/null)
if [[ "$HAS_AUTH_NONE" -gt 0 && "$HAS_MANUAL_APIKEY" -gt 0 ]]; then
  ERRORS="$ERRORS\nWARN: HTTP Request node uses authentication:none with manual apikey header. Use predefinedCredentialType with supabaseApi credential instead. Check existing credentials: GET /api/v1/credentials"
fi

if [[ -n "$ERRORS" ]]; then
  echo -e "n8n workflow validation:$ERRORS"
  exit 1
fi

exit 0
