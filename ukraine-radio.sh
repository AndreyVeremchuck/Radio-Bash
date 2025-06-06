#!/bin/bash

# --- КОНФІГУРАЦІЯ ДОДАТКУ ---
PLAYER="mpv"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
# ANIM_DELAY тепер використовується лише для індикатора завантаження, якщо його додати.
STATUS_FILE="/tmp/radio_status.tmp" # Тимчасовий файл для статусу
MPV_SOCKET="/tmp/mpv_socket" # Сокет для керування mpv

# Включити строгий режим виконання
set -euo pipefail # Вихід при помилках, невизначених змінних, помилках в конвеєрах

# --- КОЛЬОРИ (ВІДКЛЮЧЕНО ЗА ЗАМОВЧУВАННЯМ ДЛЯ СУМІСНОСТІ) ---
ENABLE_COLORS="false" # Змініть на "true", якщо ваш термінал коректно відображає ANSI-коди

# ANSI Коди для кольорів та стилів
if [ "$ENABLE_COLORS" = "true" ]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m'
    BOLD='\033[1m'
    ITALIC='\033[3m'
    UNDERLINE='\033[4m'
else
    GREEN='' BLUE='' YELLOW='' RED='' PURPLE='' CYAN='' WHITE='' NC='' BOLD='' ITALIC='' UNDERLINE=''
fi

# --- УТИЛІТНІ ФУНКЦІЇ ДЛЯ TPUT (КЕРУВАННЯ ТЕРМІНАЛОМ) ---
clear_screen() { tput clear; }
save_cursor() { tput sc; }
restore_cursor() { tput rc; }
hide_cursor() { tput civis; }
show_cursor() { tput cnorm; }
goto_xy() { tput cup "$1" "$2"; }
erase_line() { tput el; } # Очистити від курсора до кінця рядка
get_terminal_height() { tput lines; }
get_terminal_width() { tput cols; } # Додано для майбутнього використання

# --- Анімаційний спінер (використовуватиметься для індикації завантаження) ---
SPINNER_FRAMES=( "|" "/" "-" "\\" )
SPINNER_FRAME_COUNT=${#SPINNER_FRAMES[@]}

# --- АКТУАЛЬНІ URL-АДРЕСИ РАДІОСТАНЦІЙ (ОНОВЛЕНО 06.06.2025 12:15 EEST) ---
declare -A STATIONS
STATIONS[1]="106.1 FM|http://109.251.190.11:8888/live"
STATIONS[2]="Akkerman FM|https://stream.zeno.fm/fs7e5zt06qzuv?zs=UpMrSXSuSICt3jfcGoIPPg"
STATIONS[3]="Armiya FM|https://icecast.armyfm.com.ua:8443/ArmyFM"
STATIONS[4]="Avtokhvylia|https://radio.moa.org.ua/Avtohvylia"
STATIONS[5]="Best FM|http://radio.bestfm.ua:8001/bestfm"
STATIONS[6]="Boguslav FM|https://complex.in.ua/b320" # Обрано одне з посилань
STATIONS[7]="Borispol FM|http://91.219.253.226:8000/borispilfm"
STATIONS[8]="Brody FM|https://complex.in.ua/brodyHD"
STATIONS[9]="Bukovynsʹka Khvylya|http://185.233.118.107:8000/stream"
STATIONS[10]="Buske Radio|https://complex.in.ua/buskfm"
STATIONS[11]="Classic Radio|https://online.classicradio.com.ua/ClassicRadio_HD" # Обрано одне з посилань
STATIONS[12]="DJ FM|https://cast.brg.ua/djfm_main_public_mp3_hq"
STATIONS[13]="Drimajko - Kraina FM|http://live.radioec.com.ua:8000/drimayko" # Обрано одне з посилань
STATIONS[14]="Duzhe Radio|https://ipradio.net:8443/duzheHD"
STATIONS[15]="Europa Plus Dnipro|http://217.20.173.105:8100/live"
STATIONS[16]="FM Galychyna|https://stream320.galychyna.fm/WebSite"
STATIONS[17]="Fresh FM|http://193.53.83.3:8000/fresh-fm_mp3"
STATIONS[18]="Golos Prykarpattya|https://complex.in.ua/stsambir"
STATIONS[19]="Golos Stryia|https://complex.in.ua/struy"
STATIONS[20]="Hit FM|https://www.hitfm.ua/HitFM.m3u" # Обрано одне з посилань
STATIONS[21]="Hromadske Radio|http://91.218.212.67:8000/stream-ps-hi" # Обрано одне з посилань
STATIONS[22]="Hutsulska Stolytsya|http://37.157.242.104:35444/Stream.mp3"
STATIONS[23]="Informator FM|https://main.inf.fm:8101/;" # Обрано одне з посилань
STATIONS[24]="Kazki|https://radio.nrcu.gov.ua:8443/kazka-mp3"
STATIONS[25]="Kiss FM|https://online.kissfm.ua/KissFM"

PLAYER_PID=""
CURRENT_SELECTION=1
MAX_STATION_INDEX=${#STATIONS[@]}

# --- ФУНКЦІЇ КЕРУВАННЯ ПРОГРАВАЧЕМ (MPV) ---

# Оновлює файл статусу
update_status_file() {
    printf "PLAYING=%s\n" "$1" > "$STATUS_FILE"
    printf "STATION_NAME='%s'\n" "$2" >> "$STATUS_FILE"
    printf "PAUSED=%s\n" "$3" >> "$STATUS_FILE"
    printf "MUTED=%s\n" "$4" >> "$STATUS_FILE"
}

# Зупиняє поточний процес MPV
stop_player() {
    if [ -n "$PLAYER_PID" ]; then
        kill "$PLAYER_PID" 2>/dev/null || true # kill - ігноруємо помилки, якщо процес вже помер
        wait "$PLAYER_PID" 2>/dev/null || true # wait - ігноруємо помилки
        PLAYER_PID=""
    fi
    if [ -S "$MPV_SOCKET" ]; then
        rm -f "$MPV_SOCKET" 2>/dev/null || true
    fi
    update_status_file "false" "" "false" "false"
}

# Запускає відтворення обраної станції
play_station() {
    local url="$1"
    local name="$2"
    stop_player # Зупиняємо попередній програвач, якщо є

    # Додамо тимчасову індикацію завантаження
    draw_loading_status "Завантаження: ${name}..." &
    LOADING_PID=$!

    # Запуск mpv з параметрами для фонового відтворення без відео
    # --no-terminal щоб mpv не виводив власні логи на екран
    mpv --no-video --input-media-keys=no --user-agent="$USER_AGENT" \
        --no-terminal --input-ipc-server="$MPV_SOCKET" \
        --network-timeout=5 --idle --force-seekable=no "$url" < /dev/null &
    PLAYER_PID=$!

    # Чекаємо трохи, щоб mpv мав час запуститися або згенерувати помилку
    sleep 1

    # Зупиняємо індикацію завантаження
    kill "$LOADING_PID" 2>/dev/null || true
    wait "$LOADING_PID" 2>/dev/null || true # Чекаємо завершення фонового процесу

    # Перевіряємо, чи mpv справді запустився
    if ps -p "$PLAYER_PID" > /dev/null; then
        update_status_file "true" "$name" "false" "false"
    else
        update_status_file "false" "" "false" "false"
        # Можливо, варто додати повідомлення про помилку
        # draw_error_message "Не вдалося запустити станцію: ${name}"
    fi
}

# Функція для відображення індикації завантаження (як окремий потік)
draw_loading_status() {
    local message="$1"
    local spinner_idx=0
    local term_height=$(get_terminal_height)
    local status_line=$((term_height - 1))
    
    # Якщо термінал дуже маленький, обрізаємо статус-рядок, щоб він вміщався
    if [ "$status_line" -lt 0 ]; then status_line=0; fi

    while true; do
        save_cursor
        hide_cursor
        goto_xy "$status_line" 0
        erase_line
        local spinner_char="${SPINNER_FRAMES[$spinner_idx]}"
        echo -n -e "${YELLOW}${BOLD}[${spinner_char}] ${message}${NC}"
        restore_cursor
        spinner_idx=$(( (spinner_idx + 1) % SPINNER_FRAME_COUNT ))
        sleep 0.1
    done
}


# Перемикає паузу/відтворення
toggle_pause() {
    if [ -n "$PLAYER_PID" ] && [ -S "$MPV_SOCKET" ]; then
        echo '{ "command": ["cycle", "pause"] }' | socat - "$MPV_SOCKET" 2>/dev/null || true
        # Оновлюємо статус
        source "$STATUS_FILE" # Перечитуємо поточний статус
        if [ "$PAUSED" == "true" ]; then # Якщо був на паузі, то тепер відтворюється
            update_status_file "true" "$STATION_NAME" "false" "$MUTED"
        else # Якщо відтворювався, то тепер на паузі
            update_status_file "true" "$STATION_NAME" "true" "$MUTED"
        fi
    fi
}

# Перемикає увімкнення/вимкнення звуку
toggle_mute() {
    if [ -n "$PLAYER_PID" ] && [ -S "$MPV_SOCKET" ]; then
        echo '{ "command": ["cycle", "mute"] }' | socat - "$MPV_SOCKET" 2>/dev/null || true
        # Оновлюємо статус
        source "$STATUS_FILE" # Перечитуємо поточний статус
        if [ "$MUTED" == "true" ]; then # Якщо був вимкнений, то тепер увімкнений
            update_status_file "true" "$STATION_NAME" "$PAUSED" "false"
        else # Якщо увімкнений, то тепер вимкнений
            update_status_file "true" "$STATION_NAME" "$PAUSED" "true"
        fi
    fi
}

# --- ФУНКЦІЇ ДЛЯ ВІДОБРАЖЕННЯ МЕНЮ ---
# Відображає основне меню, станції та статус
show_menu() {
    clear_screen # Повне очищення ВСЬОГО екрану
    hide_cursor  # Приховуємо курсор на час малювання

    local current_line=1 # Початковий рядок для виводу

    # Заголовок
    goto_xy $current_line 0; echo -e "${BOLD}${BLUE}--- Радіо Термінал (Bash) ---${NC}"
    current_line=$((current_line + 1))
    goto_xy $current_line 0; echo -e "${BLUE}-----------------------------------${NC}"
    current_line=$((current_line + 1))
    goto_xy $current_line 0; echo -e "${BOLD}Оберіть станцію (стрілки ВГОРУ/ВНИЗ, ENTER для вибору):${NC}"
    current_line=$((current_line + 2)) # Відступ перед списком станцій

    local menu_start_line=$current_line # Рядок, з якого починається список станцій

    local current_playing_name=""
    local PLAYING="false"
    local PAUSED="false"
    local MUTED="false"
    if [ -f "$STATUS_FILE" ]; then
        source "$STATUS_FILE"
        current_playing_name="$STATION_NAME"
    fi

    # Вивід списку станцій
    for i in $(seq 1 "$MAX_STATION_INDEX" | sort -n); do
        local station_info="${STATIONS[$i]}"
        local name="${station_info%%|*}"
        
        local item_color="${CYAN}"
        local prefix="  "

        goto_xy $((menu_start_line + i - 1)) 0 # Позиціонуємо курсор
        erase_line                             # Очищаємо рядок

        if [ "$i" -eq "$CURRENT_SELECTION" ]; then
            item_color="${WHITE}${BOLD}" # Підсвічуємо обрану станцію
            prefix="> "
        fi

        # Якщо ця станція грає, змінюємо її колір
        if [ "$name" = "$current_playing_name" ] && [ "$PLAYING" = "true" ]; then
             item_color="${GREEN}${BOLD}"
             if [ "$i" -eq "$CURRENT_SELECTION" ]; then
                 item_color="${WHITE}${BOLD}" # Залишаємо підсвічування, якщо обрана
             fi
        fi

        printf "%s%s%2d: %s%s\n" "$prefix" "$item_color" "$i" "$name" "$NC"
    done

    # Вивід елементів керування
    local controls_start_line=$((menu_start_line + MAX_STATION_INDEX))
    goto_xy $controls_start_line 0; echo "" # Додатковий відступ
    controls_start_line=$((controls_start_line + 1))
    goto_xy $controls_start_line 0; echo -e "${BOLD}Керування:${NC}"
    controls_start_line=$((controls_start_line + 1))
    goto_xy $controls_start_line 0; echo -e "  ${GREEN}P${NC}: Пауза/Відновити | ${RED}S${NC}: Зупинити | ${YELLOW}M${NC}: Мутувати/Розмутувати | ${PURPLE}Q${NC}: Вийти"
    controls_start_line=$((controls_start_line + 1))
    goto_xy $controls_start_line 0; echo -e "${BLUE}-----------------------------------${NC}"
    
    # Вивід статусного рядка
    local status_display_line=$((controls_start_line + 1))
    goto_xy "$status_display_line" 0
    erase_line # Очищаємо статусний рядок перед виводом
    
    local display_text=""
    if [ "$PLAYING" = "true" ]; then
        if [ "$PAUSED" = "true" ]; then
            display_text="${YELLOW}${BOLD}ПАУЗА${NC} "
        elif [ "$MUTED" = "true" ]; then
            display_text="${YELLOW}${BOLD}ЗВУК ВИМКНЕНО${NC} "
        else
            display_text="${GREEN}${BOLD}ГРАЄ${NC} "
        fi
        display_text+="Наразі грає: ${CYAN}${current_playing_name}${NC}"
    else
        display_text="${YELLOW}Наразі нічого не грає. Оберіть станцію.${NC}"
    fi
    echo -n -e "${display_text}"

    # Повертаємо курсор для введення користувача
    goto_xy $((status_display_line + 1)) 0 # Курсор після статусного рядка
    show_cursor # Показуємо курсор після малювання
}

# --- ГОЛОВНИЙ ЦИКЛ ДОДАТКУ ТА ОБРОБКА ВИХОДУ ---

# Функція для очищення ресурсів при виході
cleanup() {
    stop_player # Зупиняємо mpv
    # Якщо був запущений процес завантаження, зупиняємо його
    if [ -n "${LOADING_PID:-}" ]; then # Перевірка існування змінної
        kill "${LOADING_PID}" 2>/dev/null || true
        wait "${LOADING_PID}" 2>/dev/null || true
    fi
    rm -f "$MPV_SOCKET" "$STATUS_FILE" 2>/dev/null || true # Видаляємо тимчасові файли
    show_cursor # Показуємо курсор
    clear_screen # Очищаємо термінал
    echo -e "${PURPLE}Вихід з радіо. Бувай!${NC}" # Прощальне повідомлення
    exit 0 # Завершуємо скрипт
}

# Перехоплюємо сигнали завершення, щоб виконати cleanup
trap cleanup SIGINT SIGTERM SIGHUP
# Перехоплюємо сигнал зміни розміру вікна терміналу
trap 'show_menu' WINCH

# Ініціалізація: встановлюємо початковий статус
update_status_file "false" "" "false" "false"

# --- ОСНОВНИЙ ЦИКЛ КЕРУВАННЯ ---
while true; do
    MAX_STATION_INDEX=${#STATIONS[@]} # Оновлюємо кількість станцій на випадок змін

    show_menu # Відображаємо меню та статус
    
    # Читаємо ввід користувача
    read -rsn3 choice_char
    
    case "$choice_char" in
        "q"|"Q")
            cleanup
            ;;
        "p"|"P")
            toggle_pause
            ;;
        "m"|"M")
            toggle_mute
            ;;
        "s"|"S")
            stop_player
            ;;
        $'\x1b[A') # Стрілка вгору
            CURRENT_SELECTION=$((CURRENT_SELECTION - 1))
            if [ "$CURRENT_SELECTION" -lt 1 ]; then
                CURRENT_SELECTION=$MAX_STATION_INDEX
            fi
            ;;
        $'\x1b[B') # Стрілка вниз
            CURRENT_SELECTION=$((CURRENT_SELECTION + 1))
            if [ "$CURRENT_SELECTION" -gt "$MAX_STATION_INDEX" ]; then
                CURRENT_SELECTION=1
            fi
            ;;
        "") # Enter
            station_info="${STATIONS[$CURRENT_SELECTION]}"
            name="${station_info%%|*}"
            url="${station_info##*|}"
            play_station "$url" "$name"
            ;;
        *) # Обробка вводу цифр
            if [[ "$choice_char" =~ ^[0-9]+$ ]] && (( choice_char >= 1 && choice_char <= MAX_STATION_INDEX )); then
                CURRENT_SELECTION=$choice_char
                station_info="${STATIONS[$CURRENT_SELECTION]}"
                name="${station_info%%|*}"
                url="${station_info##*|}"
                play_station "$url" "$name"
            fi
            ;;
    esac
done
