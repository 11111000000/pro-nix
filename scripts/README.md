Performance tuning scripts and instructions

Files:
- collect-system-info.sh  : gather hardware and kernel parameters (no sudo required for most output)
- benchmark-workload.sh   : run CPU/memory/disk stress tests (skips missing tools)
- interactive-measure.sh  : measure simple command latency under CPU load (requires stress-ng)
- enable-zram-safe.sh     : safely create zram swap (requires sudo/root)
- apply-sysctl.sh         : show and optionally apply recommended sysctl values (uses sudo when applying)
- systemd-opencode-slice.example : example systemd slice file to limit agents (requires sudo to install)

Quick instructions
1. Make scripts executable:
   chmod +x scripts/*.sh

2. Gather baseline system info (no sudo needed, but some values may require sudo):
   ./scripts/collect-system-info.sh > before-system-info.txt 2>&1

3. Run benchmark workload (will run cpu/mem/disk tests; may require sudo for full visibility):
   ./scripts/benchmark-workload.sh

4. Run interactive latency measurement (requires stress-ng):
   ./scripts/interactive-measure.sh

5. To apply recommended sysctl changes (temporary):
   ./scripts/apply-sysctl.sh
   # This will call sudo internally when applying changes

6. To enable zram (optional, requires root):
   sudo ./scripts/enable-zram-safe.sh

7. To use systemd slice example:
   sudo cp scripts/systemd-opencode-slice.example /etc/systemd/system/opencode.slice
   sudo systemctl daemon-reload
   sudo systemctl start opencode.slice
   # run an agent in the slice:
   sudo systemd-run --slice=opencode.slice --scope <command>

What to send back
- before-system-info.txt
- stress-cpu.log and fio.log (from benchmark-workload)
- outputs from interactive measurement
