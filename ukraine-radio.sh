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

# --- АКТУАЛЬНІ URL-АДРЕСИ РАДІОСТАНЦІЙ (ПЕРЕВІРЕНО 21.09.2026) ---
declare -A STATIONS
STATIONS[1]="Українське радіо|http://radio.ukr.radio:8000/ur1-mp3"
STATIONS[2]="Радіо Промінь|http://radio.ukr.radio:8000/ur2-mp3"
STATIONS[3]="Радіо Культура|http://radio.ukr.radio:8000/ur3-mp3"
STATIONS[4]="Hit FM|http://online.hitfm.ua/HitFM"
STATIONS[5]="Hit FM Українські хіти|http://online.hitfm.ua/HitFM_Ukr"
STATIONS[6]="Kiss FM|https://online.kissfm.ua/KissFM_HD"
STATIONS[7]="Kiss FM Ukrainian|https://online.kissfm.ua/KissFM_Ukr"
STATIONS[8]="Radio ROKS|https://online.radioroks.ua/RadioROKS_HD"
STATIONS[9]="Radio ROKS Ballads|https://online.radioroks.ua/RadioROKS_Ballads_HD"
STATIONS[10]="Radio ROKS New Rock|https://online.radioroks.ua/RadioROKS_NewRock_HD"
STATIONS[11]="Radio ROKS Hard'n'Heavy|https://online.radioroks.ua/RadioROKS_HardnHeavy_HD"
STATIONS[12]="Мелодія FM|https://online.melodiafm.ua/MelodiaFM"
STATIONS[13]="Авторадіо|https://cast.mediaonline.net.ua/avtoradio"
STATIONS[14]="Громадське радіо|http://91.218.212.67:8000/stream"
STATIONS[15]="Радіо НВ|https://online-radio.nv.ua/radionv.mp3"
STATIONS[16]="Radio Relax|https://online.radiorelax.ua/RadioRelax"
STATIONS[17]="NRJ Ukraine|https://cast.mediaonline.net.ua/nrj320"
STATIONS[18]="Львівська хвиля|http://onair.lviv.fm:8000/lviv32.fm"
STATIONS[19]="Перець FM|https://radio.perec.fm/radio-stilnoe"
STATIONS[20]="Єдині новини|https://online-news.radioplayer.ua/RadioNews"
STATIONS[21]="DJFM|https://cast.fex.net/djfm_x"
STATIONS[22]="Lounge FM|https://cast.mediaonline.net.ua/loungefm320"
STATIONS[23]="Lux FM|http://lux.radio.tvstitch.com/kyiv/lux_adv_sd"
STATIONS[24]="Українське радіо (резерв)|http://91.218.213.49:8000/ur1-mp3"
STATIONS[25]="RockRadio UA|https://rockradioua.online:8433/rock_256"
STATIONS[26]="Kiss FM Deep|https://online.kissfm.ua/KissFM_Deep"
STATIONS[27]="Kiss FM Digital|https://online.kissfm.ua/KissFM_Digital_HD"
STATIONS[28]="Hit FM Top|http://online.hitfm.ua/HitFM_Top"
STATIONS[29]="Hit FM Best|http://online.hitfm.ua/HitFM_Best"
STATIONS[30]="Radio ROKS|http://online.radioroks.ua/RadioROKS_HD"
STATIONS[31]="Rock Ballads|http://online.radioroks.ua/RadioROKS_Ballads"
STATIONS[32]="Radio NV (резерв)|http://91.218.212.84:8000/radionv.mp3"
STATIONS[33]="Єдині новини 24|https://online-news.radioplayer.ua/RadioNews"
STATIONS[34]="Радіо Піхота|https://online.pihota.fm/listen/radio/aac64"
STATIONS[35]="Радіо Свобода|https://n04.radiojar.com/hcrb063nn3quv"
STATIONS[36]="Люкс FM|https://lux.radio.tvstitch.com/zoloti-hiti-sd"
STATIONS[37]="Радіо Максимум|http://lux.radio.tvstitch.com/kyiv/max_adv_sd"
STATIONS[38]="Львівська хвиля (резерв)|http://onair.lviv.fm:8000/lviv32.fm"
STATIONS[39]="FM Galychyna|https://stream320.galychyna.fm/WebSite"
STATIONS[40]="DJ FM|https://cast.brg.ua/djfm_main_public_mp3_hq"
STATIONS[41]="ProgressiveUA|http://92.5.38.24:8000/radio.mp3"
STATIONS[42]="Одеса радіо|https://listen6.myradio24.com/odesradio"
STATIONS[43]="Авторадіо (резерв)|https://cast.mediaonline.net.ua/avtoradio"
STATIONS[44]="Lounge FM (HD)|https://cast.mediaonline.net.ua/loungefm320"
STATIONS[45]="NRJ Ukraine (HD)|https://cast.mediaonline.net.ua/nrj320"
STATIONS[46]="Brokenbeats|https://brokenbeats.net/stream/aac"
STATIONS[47]="Перець FM|https://radio.perec.fm/radio-stilnoe"
STATIONS[48]="Radio Relax (резерв)|https://online.radiorelax.ua/RadioRelax"
STATIONS[49]="Українське радіо AAC|http://radio.ukr.radio:8000/ur1-aacplus-l"
STATIONS[50]="RockRadio UA (резерв)|https://rockradioua.online:8433/rock_256"
STATIONS[51]="Radio ROKS Classic Rock|https://online.radioroks.ua/RadioROKS_ClassicRock_HD"
STATIONS[52]="Radio Jazz Ukraine|http://jazz.ipfm.net/RadioJazz_HD"
STATIONS[53]="Radio Bayraktar|https://online.radiobayraktar.ua/RadioBayraktar"
STATIONS[54]="Radio Shanson|https://cast.brg.ua/newshanson_main_public_mp3_hq"
STATIONS[55]="Radio Jazz Gold FM|https://online.radiojazz.ua/RadioJazz_Gold"
STATIONS[56]="Мелодія FM 95.2|http://online.melodiafm.ua/MelodiaFM"
STATIONS[57]="Galychyna|https://stream320.galychyna.fm/WebSite"
STATIONS[58]="Радіо Київ 98 FM|https://cdn.vsnw.net:8943/kyiv_fm_128k"
STATIONS[59]="Radio Relax Instrumental|https://online.radiorelax.ua/RadioRelax_Instrumental_HD"
STATIONS[60]="Гуляй Радіо|https://online.radioplayer.ua/GuliayRadio"
STATIONS[61]="DJFM Dance|https://cast.brg.ua/djfmdance_main_public_mp3_hq"
STATIONS[62]="Радіо NovaLine|https://stream.novaline.net.ua/Novaline_320"
STATIONS[63]="Jazz FM 104.6|http://online.radiojazz.ua/RadioJazz"
STATIONS[64]="Radio ROKS New Rock (резерв)|http://online.radioroks.ua/RadioROKS_NewRock_HD"
STATIONS[65]="MFM Station|https://radio.mfm.ua/online128"
STATIONS[66]="Радіо Трек|http://online2.radiotrek.rv.ua:8000/AAC+_64"
STATIONS[67]="Просто Radi.O (Київ)|http://85.238.113.60:8000/PRK128"
STATIONS[68]="Люкс ФМ Українські хіти|https://lux.radio.tvstitch.com/ukrayinski-hiti-sd"
STATIONS[69]="FM Disco Melody|https://online.melodiafm.ua/MelodiaFM_Disco"
STATIONS[70]="Радіо Nostalgie|http://lux.radio.tvstitch.com/kyiv/nst_adv_sd"
STATIONS[71]="Наше Радіо HD|https://online.nasheradio.ua/NasheRadio_HD"
STATIONS[72]="Хіт ФМ Найбільші хіти|http://online.hitfm.ua/HitFM_Best_Live"
STATIONS[73]="Прямий FM|https://cast.mediaonline.net.ua/prmfm320"
STATIONS[74]="Світ FM|http://195.234.148.52:8000/"
STATIONS[75]="Країна FM|http://live.radioec.com.ua:8000/kiev"
STATIONS[76]="Громадське радіо (резерв)|http://5.9.8.20:8000/stream"
STATIONS[77]="Мелодія FM Romantic|http://online.melodiafm.ua/MelodiaFM_Romantic_Live"
STATIONS[78]="Classic Radio|https://online.classicradio.ua/ClassicRadio"
STATIONS[79]="Наше Радіо 107.9|http://online.nasheradio.ua/NasheRadio"
STATIONS[80]="Best FM 95.6|http://radio.bestfm.ua/bestfm"
STATIONS[81]="Мелодія FM Disco|http://online.melodiafm.ua/MelodiaFM_Disco_Live"
STATIONS[82]="Явір ФМ|https://complex.in.ua/Yavir"
STATIONS[83]="Radio Ppeople FM|http://ppeople.fm:8000/main"
STATIONS[84]="РокРадіо Metal|https://rockradioua.online:8433/metal_256"
STATIONS[85]="Radio ROKS Ukrainian|http://online.radioroks.ua/RadioROKS_Ukr_HD"
STATIONS[86]="Радіо Шлягер FM|https://cast.brg.ua/shanson_main_public_mp3_hq"
STATIONS[87]="Радіо Перше|https://live.radio1.com.ua/liveradio64"
STATIONS[88]="Champion Radio|http://sportradio.com.ua:8000/championradio"
STATIONS[89]="Люкс ФМ Сучасні хіти|https://lux.radio.tvstitch.com/suchasni-hiti-sd"
STATIONS[90]="Радіо РЕЙД|https://a9.asurahosting.com:7390/radio.mp3"
STATIONS[91]="Люкс ФМ Chill and Relax|https://lux.radio.tvstitch.com/chill-sd"
STATIONS[92]="УХ-Радіо|http://193.169.80.7:8001/efir"
STATIONS[93]="Радіо Kyivstar Happy Hits|https://radio.kyivstar.ua/stream/sport/master.m3u8"
STATIONS[94]="Kiss FM EDM|https://online.kissfm.ua/KissFM_HD"
STATIONS[95]="Kiss FM Digital (резерв)|https://online.kissfm.ua/KissFM_Digital_HD"
STATIONS[96]="Hit FM HD|https://online.hitfm.ua/HitFM_HD"
STATIONS[97]="Radio ROKS Hard'n'Heavy (резерв)|https://online.radioroks.ua/RadioROKS_HardnHeavy_HD"
STATIONS[98]="Авторадіо HD|https://cast.mediaonline.net.ua/avtoradio"
STATIONS[99]="Мелодія FM (резерв)|https://online.melodiafm.ua/MelodiaFM"
STATIONS[100]="Українське радіо (резерв 2)|http://91.218.213.49:8000/ur1-mp3"

PLAYER_PID=""
CURRENT_SELECTION=1
MAX_STATION_INDEX=${#STATIONS[@]}
COLUMN_SIZE=25
PAGE_SIZE=$((COLUMN_SIZE * 2)) # 50 станцій на сторінці (2 стовпчики по 25)
CURRENT_PAGE=1
MAX_PAGE=$(( (MAX_STATION_INDEX + PAGE_SIZE - 1) / PAGE_SIZE ))

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
    goto_xy $current_line 0; echo -e "${BOLD}Сторінка ${CURRENT_PAGE}/${MAX_PAGE} — стрілки ВГОРУ/ВНИЗ, ←/→, ENTER для вибору:${NC}"
    current_line=$((current_line + 2)) # Відступ перед списком станцій

    local menu_start_line=$current_line # Рядок, з якого починається список станцій
    local left_column_width=38

    local current_playing_name=""
    local PLAYING="false"
    local PAUSED="false"
    local MUTED="false"
    if [ -f "$STATUS_FILE" ]; then
        source "$STATUS_FILE"
        current_playing_name="$STATION_NAME"
    fi

    # Вивід 50 станцій поточної сторінки у двох стовпчиках по 25 пунктів.
    # CURRENT_SELECTION відносний до сторінки (1..PAGE_SIZE); global_selection —
    # абсолютний номер станції, який використовується для підсвічування.
    local page_offset=$(( (CURRENT_PAGE - 1) * PAGE_SIZE ))
    local global_selection=$((page_offset + CURRENT_SELECTION))
    for row in $(seq 0 $((COLUMN_SIZE - 1))); do
        local left_index=$((page_offset + row + 1))
        local right_index=$((page_offset + row + COLUMN_SIZE + 1))
        local left_info="${STATIONS[$left_index]}"
        local right_info="${STATIONS[$right_index]}"
        local left_name="${left_info%%|*}"
        local right_name="${right_info%%|*}"
        local left_display="${left_name:0:28}"
        local right_display="${right_name:0:28}"
        local left_color="${CYAN}"
        local right_color="${CYAN}"
        local left_prefix="  "
        local right_prefix="  "

        if [ "$left_index" -eq "$global_selection" ]; then
            left_color="${WHITE}${BOLD}"
            left_prefix="> "
        fi
        if [ "$right_index" -eq "$global_selection" ]; then
            right_color="${WHITE}${BOLD}"
            right_prefix="> "
        fi
        if [ "$left_name" = "$current_playing_name" ] && [ "$PLAYING" = "true" ]; then
            left_color="${GREEN}${BOLD}"
        fi
        if [ "$right_name" = "$current_playing_name" ] && [ "$PLAYING" = "true" ]; then
            right_color="${GREEN}${BOLD}"
        fi

        # printf "%-Ns" рахує байти, а не символи, тому кирилиця (2 байти на
        # символ у UTF-8) ламає вирівнювання. Рахуємо відступ вручну за
        # довжиною рядка в СИМВОЛАХ (${#рядок} коректно рахує символи).
        local left_pad=$(( 28 - ${#left_display} ))
        if [ "$left_pad" -lt 0 ]; then left_pad=0; fi

        goto_xy $((menu_start_line + row)) 0
        erase_line
        printf "%s%s%2d: %s%s%*s%s" \
            "$left_prefix" "$left_color" "$left_index" "$left_display" "$NC" \
            "$left_pad" "" \
            "$(printf '%*s' "$left_column_width" '')"
        printf "%s%s%2d: %s%s\n" \
            "$right_prefix" "$right_color" "$right_index" "$right_display" "$NC"
    done
    # Вивід елементів керування
    local controls_start_line=$((menu_start_line + COLUMN_SIZE))
    goto_xy $controls_start_line 0; echo "" # Додатковий відступ
    controls_start_line=$((controls_start_line + 1))
    goto_xy $controls_start_line 0; echo -e "${BOLD}Керування:${NC}"
    controls_start_line=$((controls_start_line + 1))
    goto_xy $controls_start_line 0; echo -e "  ${GREEN}Space${NC}: Пауза | ${RED}S${NC}: Стоп | ${YELLOW}M${NC}: Звук | ${PURPLE}Q${NC}: Вихід | ${CYAN}←/→${NC}: Стовпчик | ${CYAN}Tab/N${NC}: Сторінка"
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
        " "|"p"|"P")
            toggle_pause
            ;;
        "m"|"M")
            toggle_mute
            ;;
        "s"|"S")
            stop_player
            ;;
        $'\x1b[A') # Стрілка вгору
            if [ "$CURRENT_SELECTION" -le 25 ]; then
                if [ "$CURRENT_SELECTION" -eq 1 ]; then
                    CURRENT_SELECTION=25
                else
                    CURRENT_SELECTION=$((CURRENT_SELECTION - 1))
                fi
            elif [ "$CURRENT_SELECTION" -eq 26 ]; then
                CURRENT_SELECTION=50
            else
                CURRENT_SELECTION=$((CURRENT_SELECTION - 1))
            fi
            ;;
        $'\x1b[B') # Стрілка вниз
            if [ "$CURRENT_SELECTION" -le 25 ]; then
                if [ "$CURRENT_SELECTION" -eq 25 ]; then
                    CURRENT_SELECTION=1
                else
                    CURRENT_SELECTION=$((CURRENT_SELECTION + 1))
                fi
            elif [ "$CURRENT_SELECTION" -eq 50 ]; then
                CURRENT_SELECTION=26
            else
                CURRENT_SELECTION=$((CURRENT_SELECTION + 1))
            fi
            ;;
        $'\x1b[D') # Стрілка вліво — перейти до лівого стовпчика
            if [ "$CURRENT_SELECTION" -gt 25 ]; then
                CURRENT_SELECTION=$((CURRENT_SELECTION - 25))
            fi
            ;;
        $'\x1b[C') # Стрілка вправо — перейти до правого стовпчика
            if [ "$CURRENT_SELECTION" -le 25 ]; then
                CURRENT_SELECTION=$((CURRENT_SELECTION + 25))
            fi
            ;;
        $'\t'|"n"|"N") # Tab або N — перемкнути сторінку (1-50 / 51-100)
            CURRENT_PAGE=$((CURRENT_PAGE % MAX_PAGE + 1))
            ;;
        "") # Enter
            global_index=$(( (CURRENT_PAGE - 1) * PAGE_SIZE + CURRENT_SELECTION ))
            station_info="${STATIONS[$global_index]}"
            name="${station_info%%|*}"
            url="${station_info##*|}"
            play_station "$url" "$name"
            ;;
        *) # Обробка вводу цифр (глобальний номер станції 1..MAX_STATION_INDEX)
            if [[ "$choice_char" =~ ^[0-9]+$ ]] && (( choice_char >= 1 && choice_char <= MAX_STATION_INDEX )); then
                CURRENT_PAGE=$(( (choice_char - 1) / PAGE_SIZE + 1 ))
                CURRENT_SELECTION=$(( (choice_char - 1) % PAGE_SIZE + 1 ))
                station_info="${STATIONS[$choice_char]}"
                name="${station_info%%|*}"
                url="${station_info##*|}"
                play_station "$url" "$name"
            fi
            ;;
    esac
done
