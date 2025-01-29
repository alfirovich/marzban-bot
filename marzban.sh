#!/bin/bash

# Импорт переменных из шаблона
EVENT="{{ event_name }}"
SESSION_ID="{{ user.gen_session.id }}"
API_URL="{{ config.api.url }}"
MARZBAN_HOST="{{ server.settings.panel.link }}"
SUDO_USERNAME="{{ server.settings.panel.username }}"
SUDO_PASSWORD="{{ server.settings.panel.password }}"

export TZ="Europe/Moscow"

# Логирование
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_token() {
    local token_url="$MARZBAN_HOST/api/admin/token"
    local token


    log "Marzban host: $MARZBAN_HOST"

    # Получаем токен
    token=$(curl -sk -X POST "$token_url" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "grant_type=password&username=$SUDO_USERNAME&password=$SUDO_PASSWORD" \
        | jq -r '.access_token')

    # Проверяем, удалось ли получить токен
    if [ -z "$token" ]; then
        log "Ошибка: не удалось получить токен. Проверьте статус контейнеров Docker."
        exit 1
    fi

    # Экспортируем токен
    export TOKEN="$token"
}

# Проверка доступности API
check_api() {
    local url=$1
    log "Проверка доступности API: $url..."
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "$url")
    if [ "$HTTP_CODE" != "200" ]; then
        log "Ошибка: API недоступен. Код ответа: $HTTP_CODE"
        exit 1
    fi
    log "API доступен."
}

# Основной код
log "Событие: $EVENT"


# Обработка событий
case $EVENT in
    TEST)
        log "Тестирование подключения к Marzban..."
        get_token
        log "Токен: $TOKEN"
        ;;

    INIT)
        log "Инициализация интеграции с Marzban..."
        get_token
        check_api "$API_URL/shm/v1/test"
        ;;

    CREATE)
        log "Создание пользователя..."
        get_token
        {{ service = service.id(us.service_id) }}
        expire_datetwentyonemin=$(date +'%Y-%m-%d %T' --date="{{ us.expire }} UTC + 21 minutes")
        EXPIRE_DATE=$(date --date="$expire_datetwentyonemin" '+%s')

        USER_NOTE="{{ user.login }}, https://t.me/{{ user.settings.telegram.login }}, service_id: {{ us.user_service_id }}"

        if [ -z "{{ us.settings.data.username }}" ]; then
            log "Создание нового пользователя (не вручную)..."
            PAYLOAD=$(cat <<-EOF
            {
                "username": "us_{{ us.id }}",
                "proxies": {
                    "vless": {"flow": "xtls-rprx-vision"}
                },
                "data_limit": 107374182400,
                "expire": $EXPIRE_DATE,
                "data_limit_reset_strategy": "month",
                "status": "active",
                "note": "$USER_NOTE",
                "inbounds": {{ toJson(service.settings.inbounds) }}
            }
EOF
            )
            log "Отправка запроса на создание пользователя..."
            log "Payload: $PAYLOAD"
            USER_CFG=$(curl -sk -XPOST \
                "$MARZBAN_HOST/api/user" \
                -H "Authorization: Bearer $TOKEN" \
                -H 'Content-Type: application/json' \
                -d "$PAYLOAD")
            log "Ответ от Marzban: $USER_CFG"
        else
            log "Обновление конфигурации пользователя (создан вручную)..."
            USER_CFG=$(curl -sk -XGET \
                "$MARZBAN_HOST/api/user/{{ us.settings.data.username }}" \
                -H "Authorization: Bearer $TOKEN" \
                -H 'accept: application/json')
            log "Ответ от Marzban: $USER_CFG"
        fi

        if [ -z "$(echo "$USER_CFG" | jq -r '.username')" ]; then
            log "Ошибка: Не удалось создать/обновить пользователя. Ответ: $USER_CFG"
            exit 1
        fi

        log "Загрузка конфигурации пользователя в SHM..."
        curl -sk -XPUT \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: application/json" \
            "$API_URL/shm/v1/storage/manage/vpn_mrzb_{{ us.id }}" \
            --data-binary "$USER_CFG"
        ;;

    ACTIVATE|BLOCK|PROLONGATE|CHANGED)
        log "Обработка события: $EVENT..."
        get_token
        expire_datetwentyonemin=$(date +'%Y-%m-%d %T' --date="{{ us.expire }} UTC + 21 minutes")
        EXPIRE_DATE=$(date --date="$expire_datetwentyonemin" '+%s')

        USERNAME="{{ us.settings.data.username }}"

        if [ -z "$USERNAME" ]; then
            USERNAME="us_{{ us.id }}"
        fi

        case $EVENT in
            ACTIVATE)
                PAYLOAD='{"expire": '$EXPIRE_DATE', "status": "active"}'
                ;;
            BLOCK)
                PAYLOAD='{"expire": '$EXPIRE_DATE', "status": "disabled"}'
                ;;
            PROLONGATE)
                PAYLOAD='{"expire": '$EXPIRE_DATE', "status": "active"}'
                ;;
            CHANGED)
                PAYLOAD='{"expire": '$EXPIRE_DATE'}'
                ;;
        esac

        log "Отправка запроса на обновление пользователя $USERNAME..."
        log "Payload: $PAYLOAD"
        USER_CFG=$(curl -sk -XPUT \
            "$MARZBAN_HOST/api/user/$USERNAME" \
            -H "Authorization: Bearer $TOKEN" \
            -H 'Content-Type: application/json' \
            -d "$PAYLOAD")
        log "Ответ от Marzban: $USER_CFG"

        if [ -z "$(echo "$USER_CFG" | jq -r '.username')" ]; then
            log "Ошибка: Не удалось обновить пользователя. Ответ: $USER_CFG"
            exit 1
        fi

        log "Обновление конфигурации пользователя в SHM..."
        curl -sk -XPOST \
            -H "session-id: $SESSION_ID" \
            -H "Content-Type: application/json" \
            "$API_URL/shm/v1/storage/manage/vpn_mrzb_{{ us.id }}" \
            --data-binary "$USER_CFG"
        ;;

    REMOVE)
        log "Удаление пользователя..."
        get_token
        USERNAME="{{ us.settings.data.username }}"

        if [ -z "$USERNAME" ]; then
            USERNAME="us_{{ us.id }}"
        fi

        log "Отправка запроса на удаление пользователя..."
        curl -sk -XDELETE \
            "$MARZBAN_HOST/api/user/$USERNAME" \
            -H "Authorization: Bearer $TOKEN"

        log "Удаление ключа пользователя из SHM..."
        curl -sk -XDELETE \
            -H "session-id: $SESSION_ID" \
            "$API_URL/shm/v1/storage/manage/vpn_mrzb_{{ us.id }}"
        ;;

    *)
        log "Неизвестное событие: $EVENT. Продолжаем работу."
        exit 0
        ;;
esac
