#!/usr/bin/env bash
# YAMusic Manager
# version: 1.0.0 Saturn
# by Sh. Shirakawa

set -euo pipefail

VERSION="1.0.0 Saturn"
AUTHOR="Sh. Shirakawa"

APP_NAME="Яндекс Музыка"
APP_DIR="/opt/$APP_NAME"
APP_BIN="$APP_DIR/yandexmusic"
DOWNLOAD_URL="https://desktop.app.music.yandex.net/stable/Yandex_Music.deb"

TMP_DIR=""
PACKAGE_FILE=""
CONTROL_FILE=""
DATA_FILE=""
LOCK_FILE="/tmp/yamusic.lock"

exec 9>"$LOCK_FILE"

flock -n 9 || {
    echo "Ошибка: yamusic уже запущен"
    exit 1
}

cleanup() {
    [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "$TMP_DIR"
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
    echo "  install      — установить Яндекс Музыку"
    echo "  update       — обновить Яндекс Музыку"
    echo "  delete       — удалить Яндекс Музыку"
    echo "  repair       — восстановить установку"
    echo "  launch       — запустить приложение"
    echo "  clean        — очистить кэш"
    echo "  status       — показать статус"
    echo "  reset        — удалить yamusic manager"
    echo "  help         — показать помощь"
    echo ""
}

confirm() {
    local message="$1"

    read -rp "$message [y/N]: " answer

    case "$answer" in
        y|Y|д|Д) return 0 ;;
        *)
            echo "Операция отменена"
            echo ""
            echo "Автор: $AUTHOR"
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
    for bin in curl ar tar rsync grep awk find flock df nohup; do
        require "$bin"
    done
}

check_architecture() {
    [[ "$(uname -m)" == "x86_64" ]] || {
        echo "Ошибка: поддерживается только x86_64"
        exit 1
    }
}

check_connection() {
    curl --head --silent --fail "$DOWNLOAD_URL" >/dev/null || {
        echo "Ошибка: сервер Яндекс Музыки недоступен"
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

create_workspace() {
    TMP_DIR="$(mktemp -d)"
    PACKAGE_FILE="$TMP_DIR/package.deb"
}

download_package() {
    echo "→ Скачивание пакета..."
    curl -L "$DOWNLOAD_URL" -o "$PACKAGE_FILE" --progress-bar
}

validate_package() {
    ar t "$PACKAGE_FILE" >/dev/null 2>&1 || {
        echo "Ошибка: пакет повреждён"
        exit 1
    }
}

detect_archives() {
    CONTROL_FILE="$(ar t "$PACKAGE_FILE" | grep '^control.tar' || true)"
    DATA_FILE="$(ar t "$PACKAGE_FILE" | grep '^data.tar' || true)"

    [[ -n "$CONTROL_FILE" ]] || {
        echo "Ошибка: control archive не найден"
        exit 1
    }

    [[ -n "$DATA_FILE" ]] || {
        echo "Ошибка: data archive не найден"
        exit 1
    }
}

perform_install() {
    check_dependencies
    check_architecture
    check_connection
    check_sudo
    check_disk_space

    create_workspace
    download_package
    validate_package
    detect_archives

    echo "→ Распаковка пакета..."

    cd "$TMP_DIR"
    ar x "$PACKAGE_FILE" >/dev/null
    tar -xf "$DATA_FILE" >/dev/null

    echo "→ Установка файлов..."

    sudo rsync -a opt/ /opt/
    sudo rsync -a usr/share/ /usr/share/

    echo "→ Настройка прав..."

    sudo chmod +x "$APP_BIN"

    if [[ -f "$APP_DIR/chrome-sandbox" ]]; then
        sudo chmod 4755 "$APP_DIR/chrome-sandbox" || true
    fi

    [[ -x "$APP_BIN" ]] || {
        echo "Ошибка: бинарный файл не найден"
        exit 1
    }

    echo "→ Обновление системного кэша..."

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
}

install_app() {
    banner
    confirm "Установить Яндекс Музыку?"

    perform_install

    echo ""
    echo "✓ Установка завершена"
    echo ""
    echo "Автор: $AUTHOR"
}

update_app() {
    banner
    confirm "Обновить Яндекс Музыку?"

    perform_install

    echo ""
    echo "✓ Обновление завершено"
    echo ""
    echo "Автор: $AUTHOR"
}

remove_app() {
    banner
    confirm "Полностью удалить Яндекс Музыку?"

    check_sudo

    echo "→ Удаление приложения..."

    [[ -d "$APP_DIR" ]] && sudo rm -rf "$APP_DIR"
    [[ -f /usr/share/applications/yandexmusic.desktop ]] && sudo rm -f /usr/share/applications/yandexmusic.desktop

    sudo find /usr/share/icons/hicolor -type f -name "yandexmusic*" -delete 2>/dev/null || true

    rm -rf ~/.config/YandexMusic
    rm -rf ~/.config/yandexmusic
    rm -rf ~/.cache/yandexmusic-updater
    rm -rf ~/.cache/YandexMusic

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true

    echo ""
    echo "✓ Приложение полностью удалено"
    echo ""
    echo "Автор: $AUTHOR"
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
        sudo chmod 4755 "$APP_DIR/chrome-sandbox" || true
    fi

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true

    echo ""
    echo "✓ Восстановление завершено"
    echo ""
    echo "Автор: $AUTHOR"
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
    echo ""
    echo "Автор: $AUTHOR"
}

clean_cache() {
    banner
    confirm "Очистить кэш Яндекс Музыки?"

    rm -rf ~/.cache/yandexmusic*
    rm -rf ~/.cache/YandexMusic*

    echo ""
    echo "✓ Кэш очищен"
    echo ""
    echo "Автор: $AUTHOR"
}

reset_manager() {
    banner
    confirm "Удалить yamusic manager?"

    local script_path
    script_path="$(command -v yamusic || true)"

    [[ -n "$script_path" ]] && sudo rm -f "$script_path"

    rm -f "$LOCK_FILE"

    echo ""
    echo "✓ yamusic manager удалён"
    echo ""
    echo "Автор: $AUTHOR"
}

show_status() {
    banner

    if [[ -x "$APP_BIN" ]]; then
        echo "✓ Яндекс Музыка установлена"
    else
        echo "✗ Яндекс Музыка не установлена"
    fi

    echo ""
    echo "Автор: $AUTHOR"
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
    reset)
        reset_manager
        ;;
    help|--help|-h)
        help_menu
        ;;
    *)
        help_menu
        ;;
esac
