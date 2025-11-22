#!/bin/bash
# Script to send notifications when service status changes
# Supports: Telegram (immediate), GitHub Issues (after 5 consecutive failures)

SERVICE_NAME="$1"
SERVICE_URL="$2"
STATUS="$3"  # "success" or "failed"
CONSECUTIVE_FAILURES="$4"  # Number of consecutive failures
ISSUE_NUMBER="$5"  # GitHub issue number if exists

STATES_FILE="public/status/.service_states.json"

# Initialize states file if it doesn't exist
if [ ! -f "$STATES_FILE" ]; then
    echo "{}" > "$STATES_FILE"
fi

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="${message}" \
            -d parse_mode="Markdown" > /dev/null
        return 0
    fi
    return 1
}

# Function to create GitHub issue
create_github_issue() {
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
        echo "Warning: GITHUB_TOKEN or GITHUB_REPO not set, skipping issue creation" >&2
        return 1
    fi

    local issue_title="🚨 $SERVICE_NAME - Problema persistente detectado"
    local first_failure_time
    if [ -f "$STATES_FILE" ]; then
        first_failure_time=$(jq -r ".[\"$SERVICE_NAME\"].first_failure_time // \"$(date '+%Y-%m-%d %H:%M:%S')\"" "$STATES_FILE" 2>/dev/null)
    else
        first_failure_time=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    
    local issue_body="El servicio **$SERVICE_NAME** ha estado caído por más de 75 minutos (5 verificaciones consecutivas).

- **URL:** $SERVICE_URL
- **Primera detección:** $first_failure_time
- **Issue creado:** $(date '+%Y-%m-%d %H:%M:%S')
- **Verificaciones fallidas:** 5/5
- **Página de estado:** https://status.osm.lat

Este issue fue creado automáticamente por el sistema de monitoreo."

    local response=$(curl -s -w "\n%{http_code}" -X POST "https://api.github.com/repos/${GITHUB_REPO}/issues" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"title\":\"${issue_title}\",\"body\":\"${issue_body}\",\"labels\":[\"incident\",\"automated\"]}")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 201 ]; then
        local issue_number=$(echo "$body" | jq -r '.number // empty' 2>/dev/null)
        if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
            echo "$issue_number"
            return 0
        fi
    else
        echo "Error creating GitHub issue: HTTP $http_code - $body" >&2
    fi
    return 1
}

# Function to close GitHub issue
close_github_issue() {
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ] || [ -z "$ISSUE_NUMBER" ]; then
        return 1
    fi

    local recovery_comment="✅ **Servicio recuperado**

El servicio **$SERVICE_NAME** ha vuelto a estar operacional.

- **URL:** $SERVICE_URL
- **Recuperado:** $(date '+%Y-%m-%d %H:%M:%S')
- **Página de estado:** https://status.osm.lat"

    # Add comment and close issue
    local comment_response=$(curl -s -w "\n%{http_code}" -X POST "https://api.github.com/repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"body\":\"${recovery_comment}\"}")

    local close_response=$(curl -s -w "\n%{http_code}" -X PATCH "https://api.github.com/repos/${GITHUB_REPO}/issues/${ISSUE_NUMBER}" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -d '{"state":"closed"}')

    return 0
}

# Handle service failure
if [ "$STATUS" = "failed" ]; then
    if [ "$CONSECUTIVE_FAILURES" -eq 1 ]; then
        # First failure - send Telegram notification immediately
        MESSAGE="🚨 *ALERTA: Servicio caído*

*Servicio:* $SERVICE_NAME
*URL:* $SERVICE_URL
*Estado:* ❌ No disponible
*Fecha:* $(date '+%Y-%m-%d %H:%M:%S')
*Ver detalles:* https://status.osm.lat

⚠️ Se monitoreará el servicio. Si el problema persiste por 5 verificaciones consecutivas, se creará un issue en GitHub."

        if send_telegram "$MESSAGE"; then
            echo "Telegram notification sent for $SERVICE_NAME (first failure)"
        fi
    elif [ "$CONSECUTIVE_FAILURES" -eq 5 ] && [ -z "$ISSUE_NUMBER" ]; then
        # 5th consecutive failure - create GitHub issue
        ISSUE_NUM=$(create_github_issue)
        if [ -n "$ISSUE_NUM" ] && [ "$ISSUE_NUM" != "null" ]; then
            echo "GitHub issue #$ISSUE_NUM created for $SERVICE_NAME"
            
            # Output issue number so health-check.sh can update the states file
            echo "ISSUE_NUMBER=$ISSUE_NUM"
            
            # Send Telegram notification about issue creation
            MESSAGE="📋 *Issue creado en GitHub*

*Servicio:* $SERVICE_NAME
*Issue:* #$ISSUE_NUM
*Estado:* El problema ha persistido por 5 verificaciones consecutivas
*Ver issue:* https://github.com/${GITHUB_REPO}/issues/$ISSUE_NUM"

            send_telegram "$MESSAGE"
        fi
    fi

# Handle service recovery
elif [ "$STATUS" = "success" ] && [ "$CONSECUTIVE_FAILURES" -gt 0 ]; then
    # Service recovered - send Telegram notification
    MESSAGE="✅ *Servicio restaurado*

*Servicio:* $SERVICE_NAME
*URL:* $SERVICE_URL
*Estado:* ✅ Operacional
*Fecha:* $(date '+%Y-%m-%d %H:%M:%S')
*Ver detalles:* https://status.osm.lat"

    if send_telegram "$MESSAGE"; then
        echo "Telegram recovery notification sent for $SERVICE_NAME"
    fi

    # Close GitHub issue if exists
    if [ -n "$ISSUE_NUMBER" ] && [ "$ISSUE_NUMBER" != "null" ] && [ "$ISSUE_NUMBER" != "0" ]; then
        if close_github_issue; then
            echo "GitHub issue #$ISSUE_NUMBER closed for $SERVICE_NAME"
        fi
    fi
fi
