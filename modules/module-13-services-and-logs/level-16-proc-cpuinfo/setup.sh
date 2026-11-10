#!/bin/bash
# Sizing render-worker: render-07 moved to new hardware, but render-worker
# still runs with the old box's settings (WORKERS=4, BUILD=generic). The
# mock can't show the real CPU, so capture/cpuinfo is a capture of the new
# box's /proc/cpuinfo. CPU model, socket count and AVX2 are random per setup. Traps: processor lines count hyperthreads; both sockets
# repeat the same (non-contiguous) core ids; CPUs without AVX2 still have
# "avx" and "avx512"-less flags that a loose grep for avx matches.
# The mock systemctl/journalctl are in bin/ and treat the sandbox as "/".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin capture etc/default etc/systemd/system/multi-user.target.wants \
         opt/render-worker/bin opt/render-worker/lib/generic opt/render-worker/lib/avx2
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo render-07 > etc/hostname
mkdir -p .lm
echo "2026-11-10 09:40:00" > .lm/now

# model | vendor | family model stepping | MHz | cache KB | core ids (one socket) | avx2?
MODELS=(
  "Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz|GenuineIntel|6 85 7|2200.000|16896|0 1 2 3 4 5 8 9 10 11 12 13|1"
  "Intel(R) Xeon(R) Gold 6230 CPU @ 2.10GHz|GenuineIntel|6 85 7|2100.000|28160|0 1 2 3 4 8 9 10 11 12 16 17 18 19 20 24 25 26 27 28|1"
  "Intel(R) Xeon(R) CPU E5-2650 v4 @ 2.20GHz|GenuineIntel|6 79 1|2200.000|30720|0 1 2 3 4 5 8 9 10 11 12 13|1"
  "AMD EPYC 7302 16-Core Processor|AuthenticAMD|23 49 0|3000.000|512|0 1 4 5 8 9 12 13 16 17 20 21 24 25 28 29|1"
  "AMD EPYC 7252 8-Core Processor|AuthenticAMD|23 49 0|3100.000|512|0 4 8 12 16 20 24 28|1"
  "Intel(R) Xeon(R) CPU E5-2680 v2 @ 2.80GHz|GenuineIntel|6 62 4|2800.000|25600|0 1 2 3 4 8 9 10 11 12|0"
  "Intel(R) Xeon(R) CPU E5-2670 0 @ 2.60GHz|GenuineIntel|6 45 7|2600.000|20480|0 1 2 3 4 5 6 7|0"
  "Intel(R) Xeon(R) CPU E5-2630 v2 @ 2.60GHz|GenuineIntel|6 62 4|2600.000|15360|0 1 2 3 4 5|0"
)
# Half of the boxes get AVX2, half don't.
if [ $((RANDOM % 2)) -eq 0 ]; then pick=$((RANDOM % 5)); else pick=$((5 + RANDOM % 3)); fi
IFS='|' read -r NAME VENDOR FMS MHZ CACHE COREIDS AVX2 <<< "${MODELS[$pick]}"
# Hyperthreading is on (as on nearly every server); two sockets on most boxes.
SOCKETS=$(( RANDOM % 3 == 0 ? 1 : 2 ))
HT=1

BASE="fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx pdpe1gb rdtscp lm constant_tsc rep_good nopl xtopology nonstop_tsc cpuid pni pclmulqdq ssse3 cx16 pcid sse4_1 sse4_2 x2apic popcnt aes xsave avx"
case "$VENDOR:$AVX2" in
  GenuineIntel:1) FLAGS="$BASE f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault invpcid_single ssbd ibrs ibpb stibp fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm rdt_a avx512f avx512dq rdseed adx smap clflushopt clwb avx512cd avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc arat pku ospke avx512_vnni md_clear flush_l1d arch_capabilities"
                  case "$NAME" in *E5-2650*) FLAGS="${FLAGS// avx512f avx512dq/}"; FLAGS="${FLAGS// avx512cd avx512bw avx512vl/}"; FLAGS="${FLAGS// avx512_vnni/}"; FLAGS="${FLAGS// clwb/}"; FLAGS="${FLAGS// pku ospke/}";; esac ;;
  AuthenticAMD:1) FLAGS="$BASE f16c rdrand lahf_lm cmp_legacy svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw ibs skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb cat_l3 cdp_l3 hw_pstate ssbd mba ibrs ibpb stibp vmmcall fsgsbase bmi1 avx2 smep bmi2 cqm rdt_a rdseed adx smap clflushopt clwb sha_ni xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local clzero irperf xsaveerptr rdpru wbnoinvd amd_ppin arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold avic v_vmsave_vmload vgif v_spec_ctrl umip rdpid overflow_recov succor smca sev sev_es" ;;
  *) FLAGS="$BASE"; case "$NAME" in *v2*) FLAGS="$FLAGS f16c rdrand";; esac
     FLAGS="$FLAGS lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts md_clear flush_l1d" ;;
esac

read -r FAM MODEL STEP <<< "$FMS"
if [ "$VENDOR" = GenuineIntel ]; then MICROCODE=0x5003604; else MICROCODE=0x830107a; fi
CORES=$(echo $COREIDS | wc -w | tr -d ' ')
THREADS=$((HT + 1))
SIBLINGS=$((CORES * THREADS))
# Linux numbers the first thread of every core on every socket first, then
# the hyperthread siblings.
cpu=0
for t in $(seq 0 $HT); do
  for s in $(seq 0 $((SOCKETS - 1))); do
    for c in $COREIDS; do
      apic=$(( s * 64 + c * 2 + t ))
      printf 'processor\t: %d\nvendor_id\t: %s\ncpu family\t: %s\nmodel\t\t: %s\nmodel name\t: %s\nstepping\t: %s\n' \
        "$cpu" "$VENDOR" "$FAM" "$MODEL" "$NAME" "$STEP"
      printf 'microcode\t: %s\ncpu MHz\t\t: %s\ncache size\t: %s KB\nphysical id\t: %d\nsiblings\t: %d\ncore id\t\t: %d\ncpu cores\t: %d\n' \
        "$MICROCODE" "$MHZ" "$CACHE" "$s" "$SIBLINGS" "$c" "$CORES"
      printf 'apicid\t\t: %d\ninitial apicid\t: %d\nfpu\t\t: yes\nfpu_exception\t: yes\ncpuid level\t: %d\nwp\t\t: yes\nflags\t\t: %s\n' \
        "$apic" "$apic" $(( FAM == 6 ? 22 : 16 )) "$FLAGS"
      printf 'bugs\t\t: spectre_v1 spectre_v2 spec_store_bypass%s\nbogomips\t: %s\nclflush size\t: 64\ncache_alignment\t: 64\naddress sizes\t: %s\npower management:%s\n\n' \
        "$([ "$VENDOR" = GenuineIntel ] && echo ' swapgs taa itlb_multihit mmio_stale_data retbleed')" \
        "$(awk -v m="$MHZ" 'BEGIN { printf "%.2f", m * 2 }')" \
        "$([ "$VENDOR" = GenuineIntel ] && echo '46 bits physical, 48 bits virtual' || echo '43 bits physical, 48 bits virtual')" \
        "$([ "$VENDOR" = AuthenticAMD ] && echo ' ts ttp tm hwpstate cpb eff_freq_ro [13] [14]')"
      cpu=$((cpu + 1))
    done
  done
done > capture/cpuinfo
cat > capture/README <<EOF
Captured on render-07 after the hardware swap (2026-11-10 08:55, ticket HW-2291):
  cat /proc/cpuinfo > cpuinfo
EOF

cat > etc/default/render-worker <<'EOF'
# render-worker settings, read by render-worker.service (EnvironmentFile=).
#
# WORKERS  one render process per PHYSICAL core. Hyperthreads make the
#          renderer slower, not faster.
# BUILD    avx2 when the CPU supports AVX2, otherwise generic.
#
# Sized for the old box (1x Xeon E5-2609, 4 cores, no AVX2). Update after the hardware swap.
WORKERS=4
BUILD=generic
EOF

cat > opt/render-worker/bin/render-worker <<'EOF'
#!/bin/bash
# render-worker: starts $WORKERS render processes with the $BUILD kernels.
case "$BUILD" in
  avx2|generic) ;;
  *) echo "render-worker: unknown BUILD '$BUILD' (expected avx2 or generic)" >&2; exit 2 ;;
esac
case "$WORKERS" in
  ''|*[!0-9]*) echo "render-worker: WORKERS must be a number, got '$WORKERS'" >&2; exit 2 ;;
esac
echo "render-worker 5.2.0: loading $BUILD kernels from $LM_ROOT/opt/render-worker/lib/$BUILD"
echo "render-worker: starting $WORKERS render processes"
while :; do
  sleep 30
  echo "render-worker: queue depth $((RANDOM % 40)), $WORKERS workers busy"
done
EOF
chmod +x opt/render-worker/bin/render-worker
echo "kernels built with -mavx2 -mfma" > opt/render-worker/lib/avx2/BUILDINFO
echo "kernels built for x86-64 baseline" > opt/render-worker/lib/generic/BUILDINFO

cat > etc/systemd/system/render-worker.service <<'EOF'
[Unit]
Description=Render worker pool
After=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/default/render-worker
ExecStart=/opt/render-worker/bin/render-worker
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/render-worker.service etc/systemd/system/multi-user.target.wants/render-worker.service

bin/systemctl daemon-reload
bin/systemctl start render-worker.service >/dev/null 2>&1
