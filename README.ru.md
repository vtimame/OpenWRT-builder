# OpenWrt Builder

[![English version](https://img.shields.io/badge/lang-en-blue)](README.md)

Сборочная система OpenWrt в Docker. Поддерживает кастомные устройства, патчи и конфигурации через подключаемый submodule `custom/`.

Основана на OpenWrt **v25.12.4**.

## Требования

- Docker с buildx
- Git
- Make

## Быстрый старт

```bash
git clone --recurse-submodules <repo-url>
cd firmware
make build-system
make firmware
```

## Make-таргеты

| Таргет | Описание |
|--------|----------|
| `build-system` | Собрать Docker-образ |
| `firmware` | Собрать прошивку в контейнере |
| `shell` | Интерактивный шелл в контейнере |
| `clean` | Удалить кэш build_dir и staging_dir |

## Конфигурация

`build.sh` принимает один или несколько конфиг-файлов. Файлы конкатенируются по порядку (последнее значение побеждает), затем `make defconfig` дополняет остальное.

```bash
# По умолчанию (задано в Makefile)
make firmware

# Другие конфиги
make firmware CONFIGS="custom/configs/common.config custom/configs/mt7981.config"

# Vanilla OpenWrt без custom submodule
make firmware CONFIGS="configs/mt7981.config"
```

### Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `CONFIGS` | `custom/configs/common.config custom/configs/tr.config` | Конфиг-файлы для объединения |
| `MAKE_JOBS` | `$(nproc)` | Количество потоков |
| `MAKE_OPTS` | `V=s` | Доп. флаги make |

## Структура проекта

```
.
├── Dockerfile          # Среда сборки (Debian trixie)
├── Makefile            # Оркестрация Docker
├── build.sh            # Скрипт сборки (выполняется в контейнере)
├── configs/            # Базовые конфиги (публичные)
│   └── mt7981.config   # Минимальный target mediatek/filogic
├── custom/             # Git submodule (опционально, приватный)
│   ├── configs/        # Полные конфиги сборки
│   ├── devices/        # DTS-файлы и патчи устройств
│   └── base-files/     # Системные патчи и оверлеи
├── output/             # Образы прошивок после сборки
└── .cache/             # Персистентный кэш сборки
    ├── dl/             # Скачанные исходники
    ├── feeds/          # Пакетные фиды OpenWrt
    ├── build_dir/      # Промежуточные артефакты
    ├── staging_dir/    # Тулчейн
    └── ccache/         # Кэш компилятора
```

## Custom Submodule

Директория `custom/` опциональна. Без неё собирается vanilla OpenWrt.

Для добавления своих устройств создайте репозиторий со структурой:

```
custom/
├── configs/
│   ├── common.config       # Общий набор пакетов
│   └── <platform>.config   # Target + специфика устройств
├── devices/
│   └── <vendor>/
│       ├── files/          # DTS и board-файлы (копируются в дерево исходников)
│       └── patches/        # Патчи для существующих файлов OpenWrt
└── base-files/
    ├── etc/                # Файлы-оверлеи (banner, hostname и т.д.)
    └── *.patch             # Патчи для пакета base-files
```

Подключение:

```bash
git submodule add git@github.com:user/my-custom.git custom
```

## Кэш

Кэш сборки хранится в `.cache/`. Первая сборка скачивает всё (~40 мин), последующие используют кэш.

Полный сброс:

```bash
make clean              # Удалить build_dir + staging_dir
rm -rf .cache           # Удалить всё, включая скачанные исходники
```
