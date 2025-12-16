#!/bin/bash

LOGFILE="/opt/zimbra/log/zimbra_autorestart.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)
WEBHOOK_URL="https://discord.com/api/webhooks/????"
STATUS_FILE="/opt/zimbra/log/zimbra_last_status.txt"

send_discord_embed() {
    local TITLE="$1"
    local DESC="$2"
    local COLOR="$3"
    local FOOTER="$4"
    local TIMESTAMP="$5"
    local FIELD_NAME="$6"
    local FIELD_VALUE="$7"

    DESC_ESCAPED=$(echo "$DESC" | sed 's/\\/\\\\/g; s/"/\\"/g')
    FIELD_VALUE_ESCAPED=$(echo "$FIELD_VALUE" | sed 's/\\/\\\\/g; s/"/\\"/g')

    if [[ -n "$FIELD_NAME" ]]; then
        PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "$TITLE",
    "description": "$DESC_ESCAPED",
    "color": $COLOR,
    "timestamp": "$TIMESTAMP",
    "footer": {"text": "$FOOTER"},
    "fields": [{
      "name": "$FIELD_NAME",
      "value": "$FIELD_VALUE_ESCAPED"
    }]
  }]
}
EOF
)
    else
        PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "$TITLE",
    "description": "$DESC_ESCAPED",
    "color": $COLOR,
    "timestamp": "$TIMESTAMP",
    "footer": {"text": "$FOOTER"}
  }]
}
EOF
)
    fi

    curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" $WEBHOOK_URL >> $LOGFILE 2>&1
}

if [[ ! -f "$STATUS_FILE" ]]; then
    echo "up" > "$STATUS_FILE"
fi
LAST_STATUS=$(cat "$STATUS_FILE")

echo "===== $DATE – Checking Zimbra Services =====" | tee -a $LOGFILE

STATUS=$(su - zimbra -c "zmcontrol status" 2>&1)

DOWN=$(echo "$STATUS" | grep -i "Stopped" | awk '{$1=$1; print $1}')

TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -n "$DOWN" ]]; then
    DOWN_FIELD=$(echo "$DOWN" | paste -sd ", " -)
    echo "$DATE - Service down: $DOWN_FIELD" | tee -a $LOGFILE

    send_discord_embed "⚠ Zimbra Service DOWN - $HOSTNAME" \
        "Some Zimbra services are down!" \
        16711680 "Zimbra Service Ver 1.0" "$TIMESTAMP_ISO" "Service Down" "$DOWN_FIELD"

    echo "$DATE - Restarting ALL services..." | tee -a $LOGFILE
    send_discord_embed "🔄 Restarting Zimbra Services - $HOSTNAME" \
        "Restarting all Zimbra services..." \
        16776960 "Zimbra Service Ver 1.0" "$TIMESTAMP_ISO"

    su - zimbra -c "zmcontrol restart" >> $LOGFILE 2>&1
    sleep 15

    STATUS_AFTER=$(su - zimbra -c "zmcontrol status" 2>&1)
    STATUS_AFTER=$(echo "$STATUS_AFTER" | tail -n +2)  # skip Host line

    SERVICE_UP=()
    while IFS= read -r line; do
        STATE=$(echo "$line" | awk '{print $NF}')
        NAME=$(echo "$line" | awk '{$NF=""; print $0}' | sed 's/[[:space:]]*$//')
        if [[ "$STATE" == "Running" ]]; then
            SERVICE_UP+=("$NAME")
        fi
    done <<< "$STATUS_AFTER"

    SERVICE_UP_FIELD=$(printf "%s, " "${SERVICE_UP[@]}")
    SERVICE_UP_FIELD=${SERVICE_UP_FIELD%, } 

    send_discord_embed "✅ Zimbra Services Up After Restart - $HOSTNAME" \
        "Services running after restart:" \
        65280 "Zimbra Service Ver 1.0" "$TIMESTAMP_ISO" "Service Up" "$SERVICE_UP_FIELD"

    STILL_DOWN=$(echo "$STATUS_AFTER" | grep -i "Stopped" | awk '{$1=$1; print $1}')
    if [[ -n "$STILL_DOWN" ]]; then
        STILL_DOWN_FIELD=$(echo "$STILL_DOWN" | paste -sd ", " -)
        send_discord_embed "⚠ Zimbra Service STILL DOWN - $HOSTNAME" \
            "After restart, some services are still down!" \
            16711680 "Zimbra Service Ver 1.0" "$TIMESTAMP_ISO" "Service Down" "$STILL_DOWN_FIELD"
        echo "$DATE - ⚠ Service still down after restart: $STILL_DOWN_FIELD" | tee -a $LOGFILE
    fi

    echo "up" > "$STATUS_FILE"

    echo "$DATE - ✔ All Zimbra services check completed." | tee -a $LOGFILE

else
    if [[ "$LAST_STATUS" == "down" ]]; then
        STATUS_AFTER=$(echo "$STATUS" | tail -n +2)
        SERVICE_UP=()
        while IFS= read -r line; do
            NAME=$(echo "$line" | awk '{$NF=""; print $0}' | sed 's/[[:space:]]*$//')
            SERVICE_UP+=("$NAME")
        done <<< "$STATUS_AFTER"

        SERVICE_UP_FIELD=$(printf "%s, " "${SERVICE_UP[@]}")
        SERVICE_UP_FIELD=${SERVICE_UP_FIELD%, } 
        send_discord_embed "✅ All Zimbra Services Running - $HOSTNAME" \
            "All services are running!" \
            65280 "Zimbra Service Ver 1.0" "$TIMESTAMP_ISO" "Service Up" "$SERVICE_UP_FIELD"

        echo "All services running - alert sent after previous down" | tee -a $LOGFILE
        echo "up" > "$STATUS_FILE"
    else
        echo "$DATE - ✔ All services running. No alert sent." | tee -a $LOGFILE
    fi
fi

echo "===== Done =====" | tee -a $LOGFILE
