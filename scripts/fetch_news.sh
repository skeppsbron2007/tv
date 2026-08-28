#!/bin/bash
set -e

BASE_DIR="rawdata"
NEWS_LIST_URL="https://news-mediator.tradingview.com/news-flow/v2/news?filter=lang%3Aen&client=screener&streaming=false"
NEWS_DETAIL_URL_BASE="https://news-headlines.tradingview.com/v3/story?id="

TEMP_LIST=$(mktemp)

echo "Pobieram listę najnowszych newsów z TradingView..."
curl -s -H "User-Agent: Mozilla/5.0" "$NEWS_LIST_URL" > "$TEMP_LIST"

# Sprawdź, czy odpowiedź to poprawny JSON
if ! jq -e . >/dev/null 2>&1 < "$TEMP_LIST"; then
    echo "Błąd: Otrzymano niepoprawną odpowiedź z serwera."
    rm -f "$TEMP_LIST"
    exit 1
fi

# Przetwarzaj każdy element z listy
jq -c '.items[]?' "$TEMP_LIST" | while read -r item; do
    NEWS_ID=$(echo "$item" | jq -r '.id // empty')
    PUBLISHED=$(echo "$item" | jq -r '.published // empty')

    if [ -z "$NEWS_ID" ]; then
        continue
    fi

    # 1. Generuj hash SHA-256 z ID newsa
    ID_HASH=$(echo -n "$NEWS_ID" | sha256sum | awk '{print $1}')

    # 2. Ustal datę (katalog np. rawdata/2026-08-28/)
    if [ -n "$PUBLISHED" ] && [ "$PUBLISHED" != "null" ]; then
        DATE_DIR=$(date -u -d "@$PUBLISHED" +"%Y-%m-%d" 2>/dev/null || date -u +"%Y-%m-%d")
    else
        DATE_DIR=$(date -u +"%Y-%m-%d")
    fi

    TARGET_DIR="$BASE_DIR/$DATE_DIR"
    TARGET_FILE="$TARGET_DIR/$ID_HASH.json"

    # 3. Sprawdź, czy plik z tym hashem już istnieje
    if [ -f "$TARGET_FILE" ]; then
        continue
    fi

    mkdir -p "$TARGET_DIR"

    # Bezpieczne kodowanie ID w URL
    ENCODED_ID=$(jq -rn --arg id "$NEWS_ID" '$id|@uri')
    DETAIL_URL="${NEWS_DETAIL_URL_BASE}${ENCODED_ID}&lang=en"

    echo "Pobieram nowy news [$NEWS_ID] -> $TARGET_FILE"
    curl -s -H "User-Agent: Mozilla/5.0" "$DETAIL_URL" > "$TARGET_FILE"

    # Krótka pauza 0.2s, aby nie obciążać API
    sleep 0.2
done

rm -f "$TEMP_LIST"
echo "Zakończono sprawdzanie listy."
