# Источники

## A. Проверенные ссылки

Эти страницы были открыты и прочитаны в ходе расследования.
Указано, что именно из них взято.

### A1. Документация ядра: regulator API
https://docs.kernel.org/driver-api/regulator.html

**Что дало:** семантику `regulator_force_disable()` — «Forcibly disable the
regulator output voltage or current. NOTE this will disable the regulator
output even if other consumer devices have it enabled».
Это и есть обоснование того, почему `force_disable` гасит шину,
которую драйвер не отпускает.

### A2. Исходники Qualcomm msm: `drivers/regulator/core.c`
https://android.googlesource.com/kernel/msm/+/android-msm-hammerhead-3.4-kk-r1/drivers/regulator/core.c

**Что дало:** функцию `rdev_init_debugfs()`, где видно, что файлы создаются
**с правом записи**:
```c
mode = S_IRUGO | S_IWUSR;
debugfs_create_file("enable", mode, rdev->debugfs, reg, &reg_enable_fops);

mode = 0;
if (reg_ops->is_enabled)                  mode |= S_IRUGO;
if (reg_ops->enable || reg_ops->disable)  mode |= S_IWUSR;
debugfs_create_file("force_disable", mode, rdev->debugfs, reg, &reg_fdisable_fops);
```
Также: `use_count` и `open_count` создаются как `debugfs_create_u32(..., 0444, ...)`,
только для чтения. И `regulator_init_complete()` — логика отключения
неиспользуемых регуляторов при `has_full_constraints`.

**Оговорка:** это ветка 3.4 (hammerhead), не наше ядро. Структура debugfs
в нашем ядре совпадает по наблюдаемым именам и правам, но точные
реализации fops могут отличаться.

### A3. Обзор regulator framework (китайский)
https://lishiwen4.github.io/linux-driver/regulator

**Что дало:** описание структур `regulator_dev`, `regulation_constraints`,
`regulator_ops`; список sysfs-атрибутов (`num_users`, `suspend_mem_state`,
`suspend_disk_state`, `suspend_standby_state`); перечень событий regulator
(`REGULATOR_EVENT_FORCE_DISABLE` и др.); описание debugfs-каталогов
по одному на регулятор.

**Полезно на будущее:** sysfs-атрибуты `suspend_*_state` позволяют узнать,
что должно происходить с регулятором при уходе в сон. **Не проверялось
на нашем устройстве** — потенциально важная зацепка для главной гипотезы.

### A4. Mainline `drivers/regulator/core.c` (браузер исходников)
https://codebrowser.dev/linux/linux/drivers/regulator/core.c.html

**Что дало:** сверку с мейнлайном — в нём debugfs набор беднее
(`use_count`, `open_count`, `bypass_count`), а `enable`/`force_disable` —
это downstream-добавка Qualcomm.

### A5. Android: использование debugfs
https://source.android.com/docs/core/architecture/kernel/using-debugfs-12

**Что дало:** контекст по доступу к debugfs на Android 12+ (монтирование,
ограничения). Полезно для понимания, почему часть узлов может быть недоступна.

### A6. Патч: regulator — запрет отключения неиспользуемых регуляторов
https://patchew.org/linux/20231107190926.1185326-1-javierm@redhat.com/

**Что дало:** контекст о поведении `regulator_init_complete()` и о том,
что драйверы могут полагаться на регуляторы, включённые загрузчиком,
не запрашивая их явно. **Прямая зацепка** для вопроса, почему часть шин
остаётся включённой без явного потребителя.

### A7. Qualcomm: отладка ядра Linux
https://docs.qualcomm.com/bundle/publicresource/topics/80-70018-12/debugging_linux_kernel.html

**Что дало:** официальный контекст по `CONFIG_DYNAMIC_DEBUG` и debugfs
на платформах Qualcomm.

### A8. Коммит msm про LAB/IBB и голосование за MBG
https://android.googlesource.com/kernel/msm/+/4fcb942b419155f36bf00aa545683f21b17c1ba9%5E2..4fcb942b419155f36bf00aa545683f21b17c1ba9/

**Что дало:** упоминание, что LAB и IBB в standalone-режиме голосуют за MBG.
Относится к нашей панельной цепочке (`ab`/`ibb`/`bob`). **Не исследовано
применительно к нашему устройству**, но объясняет иерархию питания панели.

### A9. ABI: sysfs-class-regulator
https://git.zx2c4.com/linux-rng/plain/Documentation/ABI/testing/sysfs-class-regulator

**Что дало:** описание атрибутов состояния регулятора при suspend.
См. A3 — потенциально важно, не проверялось.

### A10. CONFIG_DEBUG_FS
https://www.kernelconfig.io/CONFIG_DEBUG_FS

**Что дало:** справка по опции ядра.

---

## B. Непроверенные упоминания — НЕ использовать как доказательство

В ходе сессии я ссылался на обсуждения сообщества, но **URL в контексте
не сохранились**. Восстанавливать их по памяти и тем более выдумывать
я не буду. Ниже — что именно утверждалось и что нужно найти заново.

| Утверждение | Статус | Что искать |
|---|---|---|
| Жалобы на расход 26–30 мА в простое на порте Xperia 10 III | **не подтверждено** | форум Sailfish OS, тег `xperia10iii` + `battery` / `drain` |
| Реплика про «logind и udev танцуют ночью» (приписана nephros) | **не подтверждено** | тот же форум, поиск по `udev` + `suspend` |
| Заводской Android на этом же телефоне втрое экономнее | **не подтверждено на этом экземпляре** | нужен собственный замер стока (Q22) |
| Сообщество не может найти причину несколько лет | **не подтверждено** | история тикетов порта |

**Правило для отчёта:** ни одно из этих утверждений не должно использоваться
как аргумент, пока не найден первоисточник. Все выводы расследования
опираются **только на собственные измерения** — они в `02-measurements.md`.

### Где искать
- forum.sailfishos.org — раздел Devices / Xperia 10 III
- GitHub порта: `sailfish-on-lena` / `droid-hal-lena` / `droid-config-lena`
  (точные имена репозиториев требуют проверки) — issues про power/suspend
- together.jolla.com — вопросы про battery drain на Xperia 10 III

---

## C. Собственный репозиторий

https://github.com/getclick2020/xperia10iii_sailfishOS

Публичный. Содержит этот отчёт. Читается напрямую, поэтому в будущих
сессиях можно продолжать работу, опираясь на зафиксированные результаты,
а не на память диалога.

---

## D. Первичные данные

Все сырые выводы команд приведены в тексте отчёта. Файлы замеров на телефоне:

```
/home/defaultuser/act.txt        M03  фоновая активность, 16 мин
/home/defaultuser/snap.txt       M04  58 часов, два снимка wakeup_sources
/home/defaultuser/ptest.txt      M05  8 часов, панель обесточена
/home/defaultuser/cur.txt        M06  три фазы по 5 мин
/home/defaultuser/rails.txt      M07  перебор шин + карта простоя
/home/defaultuser/sleepcur.txt   M08  чистое окно сна 20 мин
/home/defaultuser/ab.txt         M09  A/B, графика остановлена
/home/defaultuser/ab2.txt        M10  оборван
/home/defaultuser/ab3.txt        M11  загрязнён
/home/defaultuser/ab4.txt        M12  решающий A/B
/home/defaultuser/panel.txt      проверка шин после остановки графики
/home/defaultuser/panel2.txt     проверка после попытки unbind
```

**Рекомендация:** скопировать эти файлы в репозиторий в каталог `raw/` —
они первичнее любых пересказов, и по ним можно перепроверить арифметику.
Также стоит сохранить `bt-hal.rc.bak` (исходное описание сервиса Bluetooth).
