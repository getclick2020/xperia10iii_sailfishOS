# Факты по подсистемам

Всё в этом файле — **наблюдения**, а не интерпретации. Вердикты о том,
виновата подсистема или нет, вынесены в `04-hypothesis-ledger.md`.

## 1. Карта регуляторов и потребителей

Получена из подкаталогов `/sys/kernel/debug/regulator/<регулятор>/` —
имя подкаталога = имя устройства-потребителя.

### Полные имена узлов debugfs (для скриптов)

```
c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ab
c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ibb
18200000.rsc:rpmh-regulator-bobe1-pm6150a_bob
18200000.rsc:rpmh-regulator-ldoa6-pm6350_l6
18200000.rsc:rpmh-regulator-ldoa2-pm6350_l2
18200000.rsc:rpmh-regulator-ldoa3-pm6350_l3
18200000.rsc:rpmh-regulator-ldoa11-pm6350_l11
18200000.rsc:rpmh-regulator-ldoa12-pm6350_l12
18200000.rsc:rpmh-regulator-ldoa16-pm6350_l16
18200000.rsc:rpmh-regulator-ldoa18-pm6350_l18
18200000.rsc:rpmh-regulator-ldoa22-pm6350_l22
18200000.rsc:rpmh-regulator-ldoe7-pm6150a_l7
```

Обратите внимание: **`pm6150a_l7` — это `ldoe7`**, а не `ldoa7`.
Буква семейства отличается, угадывать имя нельзя.

### Потребители

| Регулятор | Напряжение | Потребители |
|---|---|---|
| `pm6350_l2` | 1800 / 1503 мВ | `88e3000.qusb-vdda18` |
| `pm6350_l3` | 3075 / 2700 мВ | `usb-pdphy@1700-vdd-pdphy`, `88e3000.qusb-vdda33` |
| `pm6350_l6` | 3000 мВ | панель (VCI) |
| `pm6350_l7` | 1700 → 1620 мВ | BT + icnss |
| `pm6350_l11` | 1800 мВ | `wcd937x-codec-cdc-vddio`, `wcd937x-codec-cdc-vdd-rxtx`, BT |
| `pm6350_l12` | 1800 мВ | **`1d84000.ufshc-vccq2`** |
| `pm6350_l16` | 880 мВ | `ae90000.qcom,dp_display-vdda-0p9`, `88e8000.ssphy-vdd` |
| `pm6350_l18` | 880 / 800 мВ | `csiphy0…3-mipi-csi-vdd1`, `88e3000.qusb-vdd`, `1d87000.ufsphy_mem-vdda-phy` |
| `pm6350_l22` | 1200 мВ | `dp_display-vdda-1p2`, `88e8000.ssphy-core`, `csiphy0…3-mipi-csi-vdd2`, `ae94000.qcom,mdss_dsi0_ctrl-vdda-1p2`, `88e3000.qusb-refgen`, `1d87000.ufsphy_mem-vdda-pll`, `1d84000.ufshc-vddp-ref-clk` |
| `pm6150a_l2` | 1304 → 1170 мВ | BT + icnss |
| `pm6150a_l7` | 2950 мВ | **`1d84000.ufshc-vcc`** |
| `pm6150a_l10` | 3000 мВ | BT + icnss |
| `pm6150a_l11` | 3000 мВ | **только icnss** |
| `pm6150a_bob` | 3296 мВ | вход для `ab`/`ibb` |
| `ab` | 0 мВ (запрош.) | `soc:qcom,dsi-display-primary-lab` |
| `ibb` | 0 мВ (запрош.) | панель (AVEE) |

Диапазоны: `ab` 4600–6100 мВ, `ibb` 800–5400 мВ, `oledb` 4925–8100 мВ.

### Цепочка питания панели

```
pm6150a_bob (3296 мВ) ──┬── ab  (AVDD, +4,6…6,1 В)
                        └── ibb (AVEE, −0,8…−5,4 В)
pm6350_l6   (3000 мВ) ───── VCI
```

Все четыре были включены при погашенной матрице. При этом **`oledb` и
`wl2864c-reg` — выключены**, то есть драйвер гасит не всё, а именно эту
цепочку оставляет.

### Что гаснет корректно при отключении кабеля

`pm6350_l2`, `pm6350_l3`, `gcc_usb30_prim_gdsc`, `qusb@88e3000`.

### Что включено в простое без кабеля (после отключения панельной цепочки)

`pm6350_l12` (UFS vccq2), `pm6350_l18`, `pm6350_l22`, `pm6150a_l7` (UFS vcc),
`pm6150a_s1_level`, `pm6150a_s1_level_ao`, `gcc_ufs_phy_gdsc`.

**Все они относятся к UFS и ядру SoC.** Периферии, которую можно обвинить,
в списке простоя не осталось.

### Нули в простое (для справки)

Все `cam_cc_*`, `npu_cc_core`, `video_cc_*`, `mdss_core_gdsc`,
`hlos1_vote_mmnoc_mmu_tbu_*`, `fpc_vana_fixed_reg_87`, `wl2864c-reg`,
`oledb`, `refgen`, `smb5-vbus`, `smb5-vconn`.

---

## 2. WLAN / WCN3990 / icnss

- WCN3990 — комбо-чип WLAN + BT + FM. WLAN обслуживает драйвер **`icnss`**,
  Bluetooth — **`bt_power`**. Подсистемы имеют **раздельные линии включения
  и сброса**, но **общие шины питания** с подсчётом ссылок.
- В `dmesg` при выключении Wi-Fi наблюдалась **полная корректная
  последовательность остановки WLAN**, однако общие шины оставались под
  напряжением.
- **`pm6150a_l11` — единственная шина без Bluetooth-потребителя, и единственная
  выключенная.** Это доказывает, что `icnss` свою работу выполняет и голоса снимает.
- Отвязка драйвера `icnss` через `unbind` **уронила ядро** (перезагрузка).
- Источник пробуждений `wlan` за 58 часов простоя **не изменился вообще**
  (1 событие в обоих снимках). `qcom_rx_wakelock`, `pmo_wow_wl`,
  `sap_dfs_wakelock`, `qcom_sap_wakelock` — все нули.

---

## 3. Bluetooth / bt_power / HAL

### Идентификация

```
/sys/bus/platform/devices/soc:bt_wcn3990/driver → .../drivers/bt_power
power/runtime_status: unsupported
power/control: auto
/sys/class/rfkill/rfkill0/state: 0   (name: hci0)
```

### Хронология загрузки (ключевая улика)

```
[  1.086974] bt_power_populate_dt_pinfo: bt-reset-gpio not provided in devicetree
[ 18.407107] droid-hal-init: starting service 'vendor.bluetooth-1-0-qti'...
[ 19.443632] bt_vreg_enable: vreg_en successful for : qca,bt-vdd-io
[ 19.444457] bt_vreg_enable: vreg_en successful for : qca,bt-vdd-xtal
[ 19.445131] bt_vreg_enable: vreg_en successful for : qca,bt-vdd-core
[ 19.446613] bt_vreg_enable: vreg_en successful for : qca,bt-vdd-pa
```

**`bt_vreg_disable` не появилось ни разу за всё время работы.**
`probe` драйвера (t=1,08 с) питание **не** включает — включает именно запуск HAL.

### Описание сервиса

```
service vendor.bluetooth-1-0-qti /vendor/bin/hw/android.hardware.bluetooth@1.0-service-qti
    class hal
    capabilities BLOCK_SUSPEND NET_ADMIN SYS_NICE
    user bluetooth
    group bluetooth diag wakelock
    writepid /dev/stune/foreground/tasks
```

Нет ни `disabled`, ни `oneshot` → автостарт с классом `hal` и
**перезапуск каждые 5 секунд при любой неудаче**.
Явные `start`/`stop` в файле есть только по свойству `vts.native_server`
и только для сборок `userdebug`/`eng`.

Отдельно: HAL имеет **`CAP_BLOCK_SUSPEND`** и входит в группу **`wakelock`** —
то есть вправе блокировать сон системы.

### Что НЕ приводило к снятию питания

| Действие | Результат |
|---|---|
| переключение Bluetooth в интерфейсе | ни одного сообщения `bt_power` в логе |
| `echo 1 / 0 > /sys/class/rfkill/rfkill0/state` | ни одного сообщения, шины не изменились |
| `setprop ctl.stop vendor.bluetooth-1-0-qti` | `init.svc…=stopped`, **шины остались** |

Вывод: **у `bt_power` нет пути освобождения питания вообще.**

### Как удалось обесточить чип

1. `chmod 000` на бинарник HAL → **бесконечный спам**:
   `cannot execv(...): Permission denied` каждые 5 с (36 попыток за 193 с).
   Это загрязняет любой замер.
2. Дополнительно **убрать `.rc` из каталога init**:
   `mv /vendor/etc/init/android.hardware.bluetooth@1.0-service-qti.rc /home/defaultuser/bt-hal.rc.bak`
   → сервис неизвестен, `dmesg | grep -c execv` = **0**, шины `use 0`.

### Состояние шин после этого

| Регулятор | Было | Стало |
|---|---|---|
| `pm6350_l7` | use 1, 1700 мВ | **use 0, 1620 мВ** |
| `pm6350_l11` | use 3 | **use 2** (остались 2 голоса кодека) |
| `pm6150a_l2` | use 1, 1304 мВ | **use 0, 1170 мВ** |
| `pm6150a_l10` | use 1 | **use 0** |
| `pm6150a_l11` | use 0 | use 0 |

Напряжения упали до значений, которые просит `icnss` — то есть шины
обслуживают только WLAN.

### Безобидные ошибки загрузки, присутствующие всегда

```
init.lena.rc:16  rm /persist/bluetooth/.bt_nv.bin   → No such file or directory
init.lena.rc:17  rmdir /persist/bluetooth           → No such file or directory
```

---

## 4. Дисплей

### Что показывает лог при гашении

```
(NULL device *): deviceless supply vdd not found, using dummy regulator
(NULL device *): deviceless supply avdd not found, using dummy regulator
Entering OFF state from 0
AOD mode OFF
@@@@ panel power off @@@@
```

`dpms` = `Off`. **Поддержка AOD в драйвере есть**, хотя в настройках Sailfish
пункта нет. `deviceless` — это `regulator_get()` с NULL-устройством; такие
потребители видны в `regulator_summary` и получают dummy-регуляторы.

### debugfs панели

Каталог: `/sys/kernel/debug/qcom,mdss_dsi_pdx213_amoled_fhd_cmd/`

```
clk_gating_config                     esd_trigger
dsi-ctrl-0                            misr_data
dsi-phy-0_allow_phy_power_off         parser
dsi-phy-0_regulator_min_datarate_bps  ulps_feature_enable
dump_info                             ulps_status
esd_check_mode                        ulps_suspend_feature_enable
```

| Параметр | Значение |
|---|---|
| `ulps_status` | N |
| `ulps_feature_enable` | Y |
| `ulps_suspend_feature_enable` | **N** (записали Y — эффекта нет) |
| `dsi-phy-0_allow_phy_power_off` | Y |
| `clk_gating_config` | **0** |
| `esd_check_mode` | чтение не дало вывода |

### Дисплейный RSC

Каталог: `/sys/kernel/debug/sde_rsc0/` → `debug_mode`, `mode_control`, `status`, `vsync_mode`

```
rsc current state: 0
wraper backoff time(ns): 310953
rsc backoff time(ns): 1
pdc backoff time(ns): 20
rsc mode threshold time(ns): 20463
frame fps:60 jitter_numer:2 jitter_denom:1 vtotal:2544 prefill lines:25
    client:rsc_enc58        state:0
    client:rsc_enc48        state:0
    client:rsc_enc28        state:0
    client:sde_power_handle state:0
hw state is not supported during idle pc
```

**Все клиенты в нуле** — через RSC панель ничего не удерживает.
`mode_control` отвечает `hw state is not supported during idle pc`.

### Что НЕ снимало питание панели

| Действие | Результат |
|---|---|
| гашение экрана, `dpms Off`, `panel power off` | шины под напряжением |
| запись `ulps_suspend_feature_enable = Y` | без эффекта |
| остановка `user@100000.service` (lipstick исчез) | шины под напряжением |
| `unbind` драйвера `msm-dsi-display` | первая попытка провалилась молча |

Драйверы в системе: `drm_dsi_ctrl`, `dsi_phy`, **`msm-dsi-display`**.
Устройство: `soc:qcom,dsi-display-primary`.

### Что сработало

`echo 1 > .../force_disable` для `ibb`, `ab`, `bob`, `l6` → **`enable` = 0**
у всех четырёх. `regulator_summary` при этом продолжает показывать `use 1`
и последние запрошенные напряжения — это ожидаемо.

---

## 5. Статистика сна

### RPMh master_stats (`/sys/power/rpmh_stats/master_stats`)

Тик **19,2 МГц**. Пересчёт при uptime 287942 с:

| Мастер | Sleep Count | Accumulated (hex) | Секунд | Доля |
|---|---|---|---|---|
| APSS | `0x103ac` = 66476 | `0x4f9f81ed94b` | 284982 | **98,97%** |
| MPSS | `0x6e` = 110 | `0x506f9634eb9` | 287891 | **99,98%** |
| ADSP | `0x764f` = 30287 | `0x5064066f5ab` | 287729 | **99,93%** |
| ADSP_ISLAND | `0x647` = 1607 | `0x8ccce0ad` | 123 | — |
| CDSP | `0x22` = 34 | `0x5071368f1e4` | 287914 | **99,99%** |

### lpm_stats (`/sys/kernel/debug/lpm_stats/`)

Каталоги: `cpu0`…`cpu7`, `cx-ret`, `l3-pc`, `l3-wfi`, `lifo`, `llcc-off`, `stats`, `suspend`.

Сводка из `stats`:

| Уровень | success | total time | failed |
|---|---|---|---|
| `[L3] l3-wfi` | 0 | 0 | — |
| `[L3] l3-pc` | 29236 | 9,073 с | 9018 |
| `[L3] cx-ret` | 635 | 5,312 с | 22 |
| `[L3] llcc-off` | 81318 | 8851,492 с | 3553 |
| **`[L3] suspend`** | **4690** | **278878,788 с** | — |

Примеры по ядрам: `cpu0 wfi` 2922077 / 1150,168 с; `cpu0 pc` 63117 / 91,022 с;
`cpu0 rail-pc` 229573 / 9488,439 с; `cpu6 rail-pc` 86792 / 10797,258 с;
`cpu7 rail-pc` 94350 / 10762,737 с.

**`[L3] suspend` — самый глубокий системный уровень, и он используется:
96,5% аптайма, средний кусок 59,5 с.** `cx-ret` относится к обычному простою,
не ко сну.

### system_sleep (`/sys/power/system_sleep/stats`)

```
RPM Mode:aosd   count:0   time in last mode(msec):0
RPM Mode:cxsd   count:0   time in last mode(msec):0
RPM Mode:ddr    count:0   time in last mode(msec):0
```

Подпись **«RPM Mode»** — это legacy-интерфейс эпохи RPM. SM6350 работает на
**RPMh**. Нули, вероятно, означают «счётчик не заполняется на этой цели»,
а не «глубокие режимы не включаются». **Трактовать как доказательство нельзя.**

### DDR (`/sys/power/ddr/residency`)

```
LPM 1: Name:0xd4  count:0  Time(msec):0     (~0%)
LPM 2: Name:0xd3  count:0  Time(msec):0     (~0%)
LPM 3: Name:0x11  count:0  Time(msec):0     (~0%)
LPM 4: Name:0xd0  count:0  Time(msec):0     (~0%)
Freq 547Mhz:  CP IDX:5   count:2  Time(msec):33    (~0%)
Freq 768Mhz:  CP IDX:7   count:1  Time(msec):0     (~0%)
Freq 1555Mhz: CP IDX:10  count:3  Time(msec):10120 (~99%)
```

**Суммарное учтённое время — 10,1 с при аптайме 289000 с.** Интерфейс учитывает
крошечный срез, его нулям и процентам верить нельзя.

### Параметры lpm_levels и cpuidle

```
/sys/module/lpm_levels/parameters/lpm_ipi_prediction: Y
/sys/module/lpm_levels/parameters/lpm_prediction:     Y
/sys/module/lpm_levels/parameters/print_parsed_dt:    N
/sys/module/lpm_levels/parameters/sleep_disabled:     N
```

В `/proc/cmdline` стоит `lpm_levels.sleep_disabled=1`, но **в рантайме `N`** —
кто-то переключает при загрузке. Глубокие состояния не отключены.

cpuidle и на `cpu0`, и на `cpu6`: состояния `C0`, `C1`, `C2`, все `disable: 0`.
Системных уровней в cpuidle нет — глубина сна решается голосами RPMh.

### Срывы засыпания

```
last_failed_step:  suspend
last_failed_errno: -16        (EBUSY)
last_failed_dev:   (пусто)
```

Пустой `last_failed_dev` при шаге `suspend` и EBUSY — отмена по активному
wakeup-источнику, а не сбой конкретного устройства.

Доля срывов стабильно **73–74%** во всех замерах, включая те, где
`bluebinder` ещё не был замаскирован.

### Спам RPMh

```
qcom_rpmh DRV:apps_rsc TCS Busy, retrying RPMH message send: addr=0x30010
rpmh_rsc_send_data: 68 callbacks suppressed
```

**335 повторов за ~53 минуты** (~6/мин), собраны во всплески по 10–70 подряд,
а не размазаны постоянным фоном. TCS — слоты отправки команд в RPMh;
«Busy, retrying» означает, что все слоты заняты и драйвер крутится в ожидании.

---

## 6. UFS

Устройство `1d84000.ufshc`. Конфигурация **оптимальная**:

```
auto_hibern8:          1000        (гибернация линии через 1 мс простоя)
clkgate_enable:        1
clkscale_enable:       1
rpm_lvl:               3
spm_lvl:               5          (самый глубокий)
spm_target_dev_state:  POWERDOWN
spm_target_link_state: OFF
power/runtime_status:  suspended
power/control:         auto
```

`/sys/kernel/debug/1d84000.ufshc/stats` → **`Input/output error`**, потому что
контроллер усыплён и регистры недоступны. Это само по себе подтверждение сна.

Шины UFS: `vcc` (`pm6150a_l7`, 2950 мВ), `vccq2` (`pm6350_l12`, 1800 мВ),
PHY (`l18`), PLL и ref-clk (`l22`). `gcc_ufs_phy_gdsc` включён в бодрствующем простое.

**Отключать шины UFS для экспериментов нельзя** — подвесит файловую систему.

---

## 7. Батарея и топливный датчик

### Паспортные данные

```
battery/charge_full:        4049000 мкА·ч
battery/charge_full_design: 4529000 мкА·ч   (89,4%)
battery/cycle_count:        143
bms/soh:                    98
bms/esr_actual:             95000  (95 мΩ)
bms/esr_nominal:            53000  (53 мΩ)
bms/real_capacity:          83
bms/real_nom_cap:           4223000 мкА·ч
bms/charge_full_raw:        0      (не заполнено)
```

**Внутреннее сопротивление почти удвоилось** (95 против 53 мΩ) — батарея
постарела. При 143 циклах и soh 98 это возрастное, не циклическое.
На постоянные 40 мА не влияет, но на автономность под нагрузкой — да.

Отчётность о ёмкости непротиворечива: `real_nom_cap` 4223 против FCC 4049.
**Гипотеза «датчик врёт о ёмкости, и потому проценты падают быстро» не проходит.**

### Обучение ёмкости

В логе: `ALG: cap_learning_update: [SOMC CL][OFF]` → позже `[SOMC CL][LERANING]`
(опечатка в коде Sony). При активном обучении появляются строки
`max bsoc/ccsoc updated. bsoc_cp:… ccsoc:…`.

**Следствие:** FCC может меняться между замерами. Читать `charge_full` каждый раз.

### Сообщения зарядника (только при подключённом кабеле)

Каждые ~13 секунд:

```
pm7250b_charger: somc_aicl_irq_handler: IRQ: aicl-done
QG-K: get_batt_id_ohm: batt_id_mv=246, batt_id_ohm=15000
ALG: cap_learning_update: [SOMC CL]… charge_status:1 …
```

Без кабеля исчезают. Удобный признак «кабель точно отключён».

### Богатый набор атрибутов bms

```
aux_temp batt_age_level batt_aging_level batt_full_current batt_profile_version
battery_raw_soc battery_type capacity capacity_raw cc_soc charge_counter
charge_full charge_full_design charge_full_raw current_avg current_now
cycle_count cycle_counts debug_battery esr_actual esr_nominal fg_reset fg_type
full_counter learning_counter learning_trial_counter power_avg power_now
real_capacity real_nom_cap real_temp recharge_counter resistance
resistance_capacitive resistance_id resistance_now scale_mode_en
soc_reporting_ready soh temp time_to_empty_avg time_to_full_avg
time_to_full_now voltage_avg voltage_max voltage_min voltage_now voltage_ocv
```

Не исследованы, но потенциально полезны: `power_now`/`power_avg`,
`voltage_ocv`, `resistance*`, `learning_counter`, `scale_mode_en`.

### Доказательство отсутствия утечки в железе

Телефон ехал транспортной компанией **около недели** и приехал с зарядом
**не менее 70%**. При 39 мА за 168 часов ушло бы 6552 мА·ч — больше полной
ёмкости 4049 мА·ч. Он приехал бы мёртвым.

**Вывод: постоянной утечки в батарее или плате нет.** Но это НЕ исключает
компонент, который потребляет только когда на него подано питание: при
выключенном телефоне шины сняты, и такой компонент молчал бы.

---

## 8. Фоновые сервисы

### bluebinder

`bluebinder.service` — «Simple proxy for using android binder based bluetooth
through vhci», прослойка между BlueZ и Android-сервисом Bluetooth.

Когда Android-HAL мёртв:

```
bluebinder_wait.sh[9655]: Waiting for bluetooth service   (раз в секунду)
bluebinder.service: Start-pre operation timed out. Terminating.
bluebinder.service: Failed with result 'timeout'.
bluebinder.service: Scheduled restart job, restart counter is at 13.
```

PID скрипта **не менялся** двадцать строк подряд — это один циклящийся скрипт,
а не толпа процессов. Форки идут от его внутреннего `sleep`/логгера.

Отключено: `systemctl mask --now bluebinder.service` →
symlink `/etc/systemd/system/bluebinder.service → /dev/null`, `inactive`,
процессов нет, журнал тихий.

**Важно:** маскировка bluebinder **не изменила** долю срывов засыпания (74%).
Он не был их причиной.

### mce

`/usr/sbin/mce --systemd` — системный сервис, **переживает остановку
пользовательской сессии**. Именно он, предположительно, удерживает wakelock'и,
когда compositor исчезает, и тем блокирует засыпание.

Связанные wakeup-источники: `mce_cpu_keepalive`, `mce_display_on`,
`mce_lpm_off`, `mce_mux`, `mce_hbtimer_dispatch`, `mce_inactivity_notify`,
`mce_tklock_notify`, `mce_bluez_wait`, `mce_input_handler`, `mce_pwrkey_stm`,
`mce_proximity_stm`, `mce_led_breathing`, `mce_rtc_wakeup`, `mce_display_stm`.

### Прочее

- `dsme_iphb_wakeup`, `dsme_rtc_input` — DSME (device state management)
- `sensorfwd_pass_data`, `SensorsHAL_WAKEUP` — сенсоры
- `sailfish-fpd`, `sailfish-fpd-slave` — отпечаток пальца
- `selinux: Unknown permission status for class system` — безобидно

---

## 9. Отпечаток пальца — странность в именах

В системе одновременно присутствуют **два разных семейства имён**:

- `soc:et6xx` — wakeup-источник (`expire_count` 3)
- `fpc_vana_fixed_reg_87` — регулятор 1800 мВ (`use 0` в простое)
- `sailfish-fpd`, `sailfish-fpd-slave` — wakeup-источники

`et6xx` — Egis Technology, `fpc` — Fingerprint Cards. Разные вендоры.
Похоже, в порту унаследованы описания обеих вариантов железа. Не исследовано,
может быть важно (см. `05-open-questions.md`).

---

## 10. Содержимое debugfs (для навигации)

Полный список `/sys/kernel/debug/` включал, помимо упомянутого:

```
1d84000.ufshc  884000.qcom,qup_uart  88e3000.qusb  adsprpc  aop_send_message
asoc  battery  binder  bluetooth  cam_req_mgr  camera_*  charger  clk  cma
cmd_db  cnss-prealloc  cnss_utils  diag  dri  drm_dp  energy_model  extfrag
gpio  iio  ion  ipa  ipahal  kgsl  lmh_monitor  lpm_stats  memblock  mhi
mmc0  msm-bus-dbg  msm_perf  npu  opp  p2p0  pci-msm  pinctrl  pm_genpd
pm_qos  pmic-votable  pwm  qcedev  qcom,mdss_dsi_pdx213_amoled_fhd_cmd
qcrypto  qgauge  ras  regmap  regulator  rmnet_ipa  rndis_ipa  sched_debug
sde_rsc0  sleep_time  sps  suspend_stats  tracing  tzdbg  usb  usb-pdphy
wakeup_sources  wlan  wlan0
```

Не исследованы, но потенциально важны для оставшейся гипотезы:
**`cmd_db`** (база ресурсов RPMh), **`aop_send_message`** (обмен с AOP),
**`pmic-votable`**, **`pm_genpd`**, **`clk`**, **`sleep_time`**, **`qgauge`**.
