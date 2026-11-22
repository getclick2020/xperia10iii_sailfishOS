#!/bin/sh
f=/home/defaultuser/ab3.txt
b=/sys/class/power_supply/bms
r=/sys/kernel/debug/regulator
s() {
  echo "T=$(date +%s) CCS=$(cat $b/cc_soc) CN=$(cat $b/current_now) CA=$(cat $b/current_avg) SS=$(cat /sys/power/suspend_stats/success) SF=$(cat /sys/power/suspend_stats/fail)"
  cat /proc/uptime
}
wait_until() {
  n=0
  while [ "$(date +%s)" -lt "$1" ]; do
    sleep 1
    n=$((n+1))
    if [ $((n % 60)) -eq 0 ]; then echo "tick $(date +%s) n=$n" >> $f; sync; fi
  done
}
echo "START $(date +%s)" > $f; sync
sleep 60
echo A_START >> $f; s >> $f 2>&1; sync
wait_until $(( $(date +%s) + 900 ))
echo A_END >> $f; s >> $f 2>&1; sync
for d in "c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ibb" "c440000.qcom,spmi:qcom,pm6150l@5:qcom,amoled-ab" "18200000.rsc:rpmh-regulator-bobe1-pm6150a_bob" "18200000.rsc:rpmh-regulator-ldoa6-pm6350_l6"; do
  ( echo 1 > "$r/$d/force_disable" ) >> $f 2>&1
  printf "%s enable=" "$d" >> $f
  cat "$r/$d/enable" >> $f 2>&1
done
sync
sleep 60
echo B_START >> $f; s >> $f 2>&1; sync
wait_until $(( $(date +%s) + 900 ))
echo B_END >> $f; s >> $f 2>&1
echo DONE >> $f; sync
poweroff
