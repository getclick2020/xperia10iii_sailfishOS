#!/bin/sh
systemctl stop user@100000.service
sleep 5
echo "session: $(systemctl is-active user@100000.service)"
echo soc:qcom,dsi-display-primary > /sys/bus/platform/drivers/msm-dsi-display/unbind 2>&1
echo "unbind exit: $?"
readlink /sys/bus/platform/devices/soc:qcom,dsi-display-primary/driver 2>&1
grep -E "^ (ab|ibb|oledb|pm6150a_bob|pm6350_l6) " /sys/kernel/debug/regulator/regulator_summary
dmesg | tail -20
