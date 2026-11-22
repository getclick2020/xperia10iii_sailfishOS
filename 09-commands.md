# Команды и скрипты

Всё проверено на устройстве. Требует root (`devel-su`).

## 1. Быстрый снимок состояния

```sh
devel-su
date +%s; cat /proc/uptime
grep . /sys/class/power_supply/battery/status /sys/class/power_supply/battery/capacity
grep . /sys/class/power_supply/bms/cc_soc /sys/class/power_supply/bms/charge_full \
       /sys/class/power_supply/bms/charge_counter /sys/class/power_supply/bms/current_now \
       /sys/class/power_supply/bms/current_avg
grep . /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
```

## 2. Только включённые регуляторы

```sh
devel-su
grep -E "^ [^ ]" /sys/kernel/debug/regulator/regulator_summary | awk '$2>0 || NR==1'
```

Если `awk` недоступен, просто весь дамп:
```sh
grep -E "^ [^ ]" /sys/kernel/debug/regulator/regulator_summary
```

## 3. Потребители конкретной шины

```sh
devel-su
R=/sys/kernel/debug/regulator
for n in pm6350_l2 pm6350_l3 pm6350_l11 pm6350_l12 pm6350_l16 pm6350_l18 pm6350_l22 pm6150a_l7; do
  d=$(ls -d $R/*-$n 2>/dev/null)
  echo "== $n"
  find "$d" -maxdepth 1 -mindepth 1 -type d 2>&1
done
```

## 4. Состояние шины: включена ли физически

```sh
devel-su
R=/sys/kernel/debug/regulator
d="18200000.rsc:rpmh-regulator-ldoa11-pm6350_l11"
grep . "$R/$d/enable" "$R/$d/force_disable" "$R/$d/use_count" "$R/$d/open_count"
```

**`enable` — авторитетен.** `use_count` и `regulator_summary` после
`force_disable` остаются прежними.

## 5. Статистика сна целиком

```sh
devel-su
cat /sys/power/rpmh_stats/master_stats
grep -E "^\[|success count|total success time|failed count" /sys/kernel/debug/lpm_stats/stats
cat /sys/power/system_sleep/stats
cat /sys/power/ddr/residency
grep . /sys/module/lpm_levels/parameters/*
grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/name \
       /sys/devices/system/cpu/cpu0/cpuidle/state*/disable
```

Помнить: `system_sleep` и `ddr/residency` — вероятно, не заполняются. См. `08`.

## 6. Кто будит и кто срывает сон

```sh
devel-su
cat /sys/kernel/debug/wakeup_sources
grep . /sys/power/suspend_stats/last_failed_dev \
       /sys/power/suspend_stats/last_failed_step \
       /sys/power/suspend_stats/last_failed_errno
```

Снимать **дважды** и считать дельты. Колонки: `wakeup_count` — отмены suspend,
`prevent_suspend_time` — сколько не дал спать, `last_change` — монотонные часы.

## 7. Проверка на циклы перезапуска (загрязнение замера)

```sh
devel-su
dmesg | grep -c execv
journalctl --since "-10min" --no-pager | tail -30
systemctl list-units --state=failed --no-pager
ps aux | grep -iE "bluebinder|wait.sh" | grep -v grep
```

Ненулевой `execv` или повторяющиеся `Scheduled restart job` = замер невалиден.

## 8. Здоровье батареи

```sh
devel-su
grep . /sys/class/power_supply/battery/charge_full \
       /sys/class/power_supply/battery/charge_full_design \
       /sys/class/power_supply/battery/cycle_count
grep . /sys/class/power_supply/bms/soh /sys/class/power_supply/bms/esr_actual \
       /sys/class/power_supply/bms/esr_nominal /sys/class/power_supply/bms/real_capacity \
       /sys/class/power_supply/bms/real_nom_cap
```

## 9. Исследование RPMh — следующий недорогой шаг

Ещё не выполнялось. Прямо относится к главной оставшейся гипотезе.

```sh
devel-su
ls /sys/kernel/debug/cmd_db/
ls /sys/kernel/debug/pmic-votable/
ls /sys/kernel/debug/aop_send_message 2>&1
ls /sys/kernel/debug/pm_genpd/ 2>&1
cat /sys/kernel/debug/sleep_time 2>&1 | head -20
```

Затем читать содержимое найденных узлов. Цель — увидеть, **кто держит голоса**
за ресурсы, не дающие SoC обесточиться.

Дополнительно, не проверялось: sysfs-атрибуты поведения регулятора при сне
```sh
ls /sys/class/regulator/ | head
grep . /sys/class/regulator/regulator.*/suspend_mem_state 2>&1 | head -40
```

---

## 10. Отработанный A/B-скрипт (универсальный)

Исправлены все известные дефекты: паузы по wall-clock, автоожидание кабеля,
heartbeat, видимый stderr, `charge_full` в каждом снимке, опциональный
`poweroff` для опасных случаев.

**Создать файл:**

```sh
cat > /home/defaultuser/abtest.sh << 'EOF'
#!/bin/sh
# A/B тока во сне. Окно A — без вмешательства, окно B — с погашенными шинами.
# Графическую сессию НЕ останавливать: её остановка блокирует засыпание.

OUT=/home/defaultuser/ab_result.txt
WINDOW=1200      # длительность каждого окна, секунды реального времени
SETTLE=120       # устаканивание, тоже по wall-clock
POWEROFF_END=0   # 1 — обязательно для шин панели; 0 — для безопасных шин

# Что гасить в окне B.
# Тест кодека (безопасно, следующий шаг):
RAILS="18200000.rsc:rpmh-regulator-ldoa11-pm6350_l11"
# Тест панели (ОПАСНО, требует POWEROFF_END=1, порядок обратный включению):
# RAILS="c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ibb c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ab 18200000.rsc:rpmh-regulator-bobe1-pm6150a_bob 18200000.rsc:rpmh-regulator-ldoa6-pm6350_l6"

B=/sys/class/power_supply/bms
R=/sys/kernel/debug/regulator

snap() {
  echo "T=$(date +%s) CCS=$(cat $B/cc_soc) CF=$(cat $B/charge_full) CC=$(cat $B/charge_counter) CN=$(cat $B/current_now) CA=$(cat $B/current_avg) SS=$(cat /sys/power/suspend_stats/success) SF=$(cat /sys/power/suspend_stats/fail)"
  cat /proc/uptime
}

wait_until() {
  n=0
  while [ "$(date +%s)" -lt "$1" ]; do
    sleep 1
    n=$((n+1))
    if [ $((n % 120)) -eq 0 ]; then
      echo "tick $(date +%s) n=$n" >> "$OUT"
    fi
  done
}

echo "START $(date +%s)" > "$OUT"

# ждём отключения кабеля
while [ "$(cat /sys/class/power_supply/battery/status)" != "Discharging" ]; do
  sleep 2
done
echo "UNPLUGGED $(date +%s)" >> "$OUT"

wait_until $(( $(date +%s) + SETTLE ))

echo A_START >> "$OUT"; snap >> "$OUT" 2>&1; sync
wait_until $(( $(date +%s) + WINDOW ))
echo A_END >> "$OUT"; snap >> "$OUT" 2>&1; sync

for d in $RAILS; do
  ( echo 1 > "$R/$d/force_disable" ) >> "$OUT" 2>&1
  printf "%s enable=" "$d" >> "$OUT"
  cat "$R/$d/enable" >> "$OUT" 2>&1
done
sync

wait_until $(( $(date +%s) + SETTLE ))

echo B_START >> "$OUT"; snap >> "$OUT" 2>&1; sync
wait_until $(( $(date +%s) + WINDOW ))
echo B_END >> "$OUT"; snap >> "$OUT" 2>&1
echo DONE >> "$OUT"; sync

if [ "$POWEROFF_END" = "1" ]; then
  poweroff
fi
EOF
cat /home/defaultuser/abtest.sh
```

**Запуск:**

```sh
devel-su
ps aux | grep abtest | grep -v grep
systemd-run --unit=abtest --collect /bin/sh /home/defaultuser/abtest.sh
systemctl is-active abtest
cat /home/defaultuser/ab_result.txt
```

Должно быть `active` и строка `START`. Затем: **погасить экран кнопкой,
отключить кабель, не трогать телефон**. Полное время ≈ 2×(SETTLE+WINDOW)
= ~44 минуты плюс небольшие перелёты.

Если `POWEROFF_END=0`, телефон останется живым — можно подключать кабель
и читать файл. Если `1` — дождаться самостоятельного выключения,
затем включить обычным образом.

**Чтение результата:**

```sh
cat /home/defaultuser/ab_result.txt
```

**Как считать:**

```
I_окна = (CCS_start − CCS_end) × 0,4049 / (Δt_секунд / 3600)   [мА]
доля бодрствования = Δidle / (8 × Δuptime)
```

**Обязательные проверки валидности:**
- `SS` **вырос** в обоих окнах (иначе телефон не спал)
- доля бодрствования ≈ 0,5% в обоих окнах
- `enable=0` у всех шин перед окном B
- `tick` идут с интервалом заметно больше 120 с (значит система спала)
- `CF` одинаков в обоих окнах (иначе масштаб поехал)

---

## 11. Постоянные изменения и их откат

### Что изменено сейчас

| Изменение | Как сделано |
|---|---|
| HAL Bluetooth не запускается | `chmod 000` на бинарник + `.rc` убран |
| `bluebinder` не запускается | `systemctl mask --now` |

### Откат Bluetooth HAL

```sh
devel-su
mv /home/defaultuser/bt-hal.rc.bak /vendor/etc/init/android.hardware.bluetooth@1.0-service-qti.rc
chmod 755 /vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti
ls -l /vendor/etc/init/android.hardware.bluetooth@1.0-service-qti.rc \
      /vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti
```
Затем перезагрузка.

### Откат bluebinder

```sh
devel-su
systemctl unmask bluebinder.service
systemctl enable bluebinder.service
systemctl start bluebinder.service
systemctl is-active bluebinder.service
```

**Важно:** `unmask` alone недостаточно, если ранее делали `disable` —
нужен ещё `enable`.

### Откат force_disable шин

**Только перезагрузка или выключение.** Запись в `enable` не работает:
`use_count` остался ≥1, и `regulator_enable()` не подаст питание на железо.

---

## 12. Ручное гашение шин (осторожно)

**Читать предупреждения в `01-methodology.md`, раздел 7, прежде чем делать.**

```sh
devel-su
R=/sys/kernel/debug/regulator
for d in "c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ibb" \
         "c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ab" \
         "18200000.rsc:rpmh-regulator-bobe1-pm6150a_bob" \
         "18200000.rsc:rpmh-regulator-ldoa6-pm6350_l6"; do
  ( echo 1 > "$R/$d/force_disable" ) 2>&1
  printf "%s enable=" "$d"; cat "$R/$d/enable"
done
```

После этого: **не включать экран, не нажимать кнопки, завершить `poweroff`.**

---

## 13. Диагностика «скрипт не работает»

Прежде чем объявлять скрипт мёртвым:

```sh
devel-su
ps aux | grep <имя_файла_результата> | grep -v grep
systemctl is-active <имя_юнита>
date +%s
cat /proc/uptime
tail -5 /home/defaultuser/<файл>.txt
```

Сравнить `date +%s` с меткой последней записи и `uptime` с записанным.
Если прошло меньше ожидаемого — скрипт просто ещё работает.
Так была предотвращена ложная тревога в M10.
