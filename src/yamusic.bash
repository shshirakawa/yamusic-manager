#!/usr/bin/env bash
# YAMusic Manager
# version: 1.2.0 Saturn
# by Sh. Shirakawa

set -euo pipefail

VERSION="1.2.0 Saturn"
AUTHOR="Sh. Shirakawa"

APP_NAME="yandex-music"
APP_DIR="/opt/$APP_NAME"
APP_BIN="$APP_DIR/yandexmusic"

DOWNLOAD_META_URL="https://desktop.app.music.yandex.net/stable/download.json"
SELF_UPDATE_URL="https://raw.githubusercontent.com/shshirakawa/yamusic-manager/refs/heads/main/src/yamusic.bash"

TMP_DIR=""
PACKAGE_FILE=""
DOWNLOAD_URL=""
LOCK_FILE="/tmp/yamusic.lock"

exec 9>"$LOCK_FILE"

flock -n 9 || {
    echo "Ошибка: yamusic уже запущен"
    exit 1
}

cleanup() {
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

banner() {
    echo "YAMusic Manager"
    echo "version $VERSION"
    echo "by $AUTHOR"
    echo ""
}

help_menu() {
    banner
    echo "Команды:"
    echo ""
    echo "install — установить Яндекс Музыку"
    echo "update — обновить Яндекс Музыку"
    echo "delete — полностью удалить Яндекс Музыку"
    echo "repair — восстановить установку"
    echo "launch — запустить приложение"
    echo "clean — очистить кэш"
    echo "status — показать статус"
    echo "self-update — обновить yamusic manager"
    echo "self-delete — удалить yamusic manager"
    # Для приличия
    echo "help — показать помощь"
    echo ""
}

confirm() {
    local message="$1"

    read -rp "$message [y/N]: " answer

    case "$answer" in
        y|Y|д|Д) return 0 ;;
        *)
            echo "Операция отменена"
            exit 0
            ;;
    esac
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Ошибка: отсутствует зависимость $1"
        exit 1
    }
}

check_dependencies() {
    for bin in curl ar tar rsync grep awk find flock df nohup jq bash sudo; do
        require "$bin"
    done
}

check_architecture() {
    [[ "$(uname -m)" == "x86_64" ]] || {
        echo "Ошибка: поддерживается только x86_64"
        exit 1
    }
}

check_sudo() {
    sudo -v
}

check_disk_space() {
    local free_kb
    free_kb=$(df /tmp --output=avail | tail -n 1)

    if (( free_kb < 700000 )); then
        echo "Ошибка: недостаточно свободного места"
        exit 1
    fi
}

version_gt() {
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" != "$2" ]]
}

get_latest_download_url() {
    local json

    echo "→ Получение актуальной версии..."

    json="$(curl \
        --fail \
        --silent \
        --show-error \
        --retry 3 \
        --retry-delay 2 \
        "$DOWNLOAD_META_URL")"

    DOWNLOAD_URL="$(printf '%s' "$json" | jq -r '.linux')"

    [[ -n "$DOWNLOAD_URL" && "$DOWNLOAD_URL" != "null" ]] || {
        echo "Ошибка: Linux package URL не найден"
        exit 1
    }
}

extract_app_version() {
    basename "$DOWNLOAD_URL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

check_connection() {
    curl --head --silent --fail "$DOWNLOAD_URL" >/dev/null || {
        echo "Ошибка: сервер Яндекс Музыки недоступен"
        exit 1
    }
}

create_workspace() {
    TMP_DIR="$(mktemp -d)"
    PACKAGE_FILE="$TMP_DIR/package.deb"
}

download_package() {
    echo "→ Скачивание пакета..."

    curl \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        --location \
        "$DOWNLOAD_URL" \
        -o "$PACKAGE_FILE"

    [[ -s "$PACKAGE_FILE" ]] || {
        echo "Ошибка: скачанный пакет пуст"
        exit 1
    }
}

validate_package() {
    ar t "$PACKAGE_FILE" >/dev/null 2>&1 || {
        echo "Ошибка: пакет повреждён"
        exit 1
    }
}

install_files() {
    echo "→ Распаковка пакета..."

    cd "$TMP_DIR"

    cp "$PACKAGE_FILE" ./package.deb
    ar x package.deb >/dev/null

    local data_archive
    data_archive="$(find . -name 'data.tar.*' | head -n1)"

    [[ -n "$data_archive" ]] || {
        echo "Ошибка: data archive не найден"
        exit 1
    }

    tar -xf "$data_archive"

    echo "→ Установка файлов..."

    sudo rsync -a opt/ /opt/
    sudo rsync -a usr/share/ /usr/share/

    sudo chmod +x "$APP_BIN"

    if [[ -f "$APP_DIR/chrome-sandbox" ]]; then
        sudo chown root:root "$APP_DIR/chrome-sandbox"
        sudo chmod 4755 "$APP_DIR/chrome-sandbox"
    fi

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
}

perform_install() {
    check_dependencies
    check_architecture
    check_sudo
    check_disk_space

    get_latest_download_url
    check_connection

    local app_version
    app_version="$(extract_app_version)"

    echo "→ Найдена версия: $app_version"

    create_workspace
    download_package
    validate_package
    install_files
}

install_app() {
    banner
    confirm "Установить Яндекс Музыку?"
    perform_install
    echo ""
    echo "✓ Установка завершена"
}

update_app() {
    banner
    confirm "Обновить Яндекс Музыку?"
    perform_install
    echo ""
    echo "✓ Обновление завершено"
}

remove_app() {
    banner
    confirm "Полностью удалить Яндекс Музыку?"

    check_sudo

    echo "→ Полный purge..."

    sudo find /opt -maxdepth 1 \
        \( -iname '*yandex*music*' -o -iname '*music*yandex*' \) \
        -exec rm -rf {} + 2>/dev/null || true

    sudo find /usr/share/applications \
        -type f \
        \( -iname '*yandex*music*.desktop' -o -iname '*music*yandex*.desktop' \) \
        -delete 2>/dev/null || true

    sudo find /usr/share/icons \
        -type f \
        \( -iname '*yandex*music*' -o -iname '*music*yandex*' \) \
        -delete 2>/dev/null || true

    sudo find /usr/share/metainfo \
        -type f \
        \( -iname '*yandex*music*' -o -iname '*music*yandex*' \) \
        -delete 2>/dev/null || true

    sudo find /usr/share/dbus-1/services \
        -type f \
        \( -iname '*yandex*music*' -o -iname '*music*yandex*' \) \
        -delete 2>/dev/null || true

    rm -rf ~/.config/YandexMusic
    rm -rf ~/.config/yandexmusic
    rm -rf ~/.local/share/YandexMusic
    rm -rf ~/.local/share/yandexmusic
    rm -rf ~/.cache/YandexMusic
    rm -rf ~/.cache/yandexmusic
    rm -rf ~/.cache/yandexmusic-updater
    rm -rf ~/.local/state/yandexmusic

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true

    echo ""
    echo "✓ Яндекс Музыка полностью удалена"
}

repair_app() {
    banner
    confirm "Восстановить установку?"

    [[ -f "$APP_BIN" ]] || {
        echo "Ошибка: приложение не установлено"
        exit 1
    }

    check_sudo

    sudo chmod +x "$APP_BIN"

    if [[ -f "$APP_DIR/chrome-sandbox" ]]; then
        sudo chown root:root "$APP_DIR/chrome-sandbox"
        sudo chmod 4755 "$APP_DIR/chrome-sandbox"
    fi

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true

    echo ""
    echo "✓ Восстановление завершено"
}

launch_app() {
    banner

    [[ -x "$APP_BIN" ]] || {
        echo "Ошибка: приложение не установлено"
        exit 1
    }

    nohup "$APP_BIN" >/dev/null 2>&1 &
    disown

    echo "✓ Яндекс Музыка запущена"
}

clean_cache() {
    banner
    confirm "Очистить кэш Яндекс Музыки?"

    rm -rf ~/.cache/yandexmusic
    rm -rf ~/.cache/yandexmusic-updater
    rm -rf ~/.cache/YandexMusic

    echo ""
    echo "✓ Кэш очищен"
}

show_status() {
    banner

    if [[ -x "$APP_BIN" ]]; then
        echo "✓ Яндекс Музыка установлена"
    else
        echo "✗ Яндекс Музыка не установлена"
    fi
}

self_update() {
    banner
    echo "→ Проверка обновлений менеджера..."

    local current_script
    local remote_script
    local remote_version

    current_script="$(command -v yamusic || true)"

    [[ -n "$current_script" ]] || {
        echo "Ошибка: yamusic не найден"
        exit 1
    }

    TMP_DIR="$(mktemp -d)"
    remote_script="$TMP_DIR/yamusic.new"

    curl \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        --location \
        "$SELF_UPDATE_URL" \
        -o "$remote_script"

    bash -n "$remote_script" || {
        echo "Ошибка: новый скрипт повреждён"
        exit 1
    }

    remote_version="$(
        grep '^VERSION=' "$remote_script" \
        | head -n1 \
        | cut -d'"' -f2
    )"

    [[ -n "$remote_version" ]] || {
        echo "Ошибка: версия обновления не найдена"
        exit 1
    }

    if version_gt "$remote_version" "$VERSION"; then
        check_sudo

        sudo cp "$current_script" "${current_script}.backup"
        sudo install -m755 "$remote_script" "$current_script"

        hash -r
        sync

        rm -f "$LOCK_FILE"
        find /tmp -maxdepth 1 -name 'yamusic*' -exec rm -rf {} + 2>/dev/null || true

        echo ""
        echo "✓ YAMusic Manager обновлён до версии $remote_version"
    else
        echo ""
        echo "✓ YAMusic Manager уже актуален ($VERSION)"
    fi
}

self_delete() {
    banner
    confirm "Удалить YAMusic Manager?"

    local script_path
    script_path="$(command -v yamusic || true)"

    check_sudo

    [[ -n "$script_path" ]] && sudo rm -f "$script_path"
    [[ -f "${script_path}.backup" ]] && sudo rm -f "${script_path}.backup"

    rm -f "$LOCK_FILE"
    find /tmp -maxdepth 1 -name 'yamusic*' -exec rm -rf {} + 2>/dev/null || true

    hash -r
    sync

    echo ""
    echo "✓ YAMusic Manager полностью удалён"
}

case "${1:-}" in
    install)
        install_app
        ;;
    update)
        update_app
        ;;
    delete)
        remove_app
        ;;
    repair)
        repair_app
        ;;
    launch)
        launch_app
        ;;
    clean)
        clean_cache
        ;;
    status)
        show_status
        ;;
    self-update)
        self_update
        ;;
    self-delete)
        self_delete
        ;;
    help|--help|-h)
        help_menu
        ;;
    *)
        help_menu
        ;;
esac
