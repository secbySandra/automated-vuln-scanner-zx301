#!/bin/bash
# Student: Sandra Golinskaya
# Student ID: s8
# Project: ZX301 - VULNERABILITY SCANNER
# Lecturer: Doron Zohar

# =========================
# Generic output filenames
# =========================
REPORT_PDF="vulnerability_report.pdf"
SUBMISSION_ZIP="scan_results.zip"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERROR] Script must be run as ROOT."
        exit 1
    fi
}

check_tools() {
    local tools=(nmap hydra searchsploit pandoc)
    for t in "${tools[@]}"; do
        if ! command -v "$t" >/dev/null 2>&1; then
            echo "[WARNING] Missing tool: $t"
        fi
    done
}

create_dirs() {
    mkdir -p "$OUTDIR"/{nmap,weak,report}
}

run_nmap_scan() {
    echo "[*] Running full Nmap scan on $NET ..."
    nmap -sS -sV -O -p- -oA "$OUTDIR/nmap/scan" "$NET"
}

extract_csv() {
    echo "[*] Creating results.csv ..."
    awk -F'[ /]' '/open/{printf "%s,%s,%s,%s,%s\n",$2,$1,$5,$4,$6}' \
        "$OUTDIR/nmap/scan.gnmap" > "$OUTDIR/report/results.csv"
}

run_vuln_scripts() {
    echo "[*] Running NSE vulnerability scan ..."
    nmap --script vuln -oA "$OUTDIR/nmap/nse_vuln" "$NET"

    echo "[*] Running Searchsploit ..."
    searchsploit --nmap "$OUTDIR/nmap/nse_vuln.xml" \
        > "$OUTDIR/report/exploits.txt"
}

run_hydra_per_host() {
    echo "[*] Running Hydra on all hosts with SSH ..."

    grep "22/open" "$OUTDIR/nmap/scan.gnmap" | awk '{print $2}' > "$OUTDIR/ssh_hosts.txt"

    while read -r host; do
        echo "[*] Hydra attack on host: $host"
        hydra -L /usr/share/wordlists/metasploit/default_users.txt \
              -P /usr/share/wordlists/rockyou.txt \
              ssh://"$host" -o "$OUTDIR/weak/hydra_$host.txt"
    done < "$OUTDIR/ssh_hosts.txt"
}

create_summary() {
    echo "[*] Building English summary report ..."

    {
        echo "=== Vulnerability Scan Report ==="
        echo "Target Network: $NET"
        echo "Mode: FULL"
        echo "Timestamp: $(date)"
        echo ""
        echo "--- Open Services ---"
        cat "$OUTDIR/report/results.csv"
        echo ""
        echo "--- Exploits Found (Searchsploit) ---"
        sed -n '1,200p' "$OUTDIR/report/exploits.txt"
    } > "$OUTDIR/report/summary.txt"
}

create_pdf() {
    echo "[*] Generating PDF report ..."
    pandoc "$OUTDIR/report/summary.txt" -o "$OUTDIR/report/$REPORT_PDF"
}

package_submission() {
    echo "[*] Creating submission ZIP ..."
    zip -j "$OUTDIR/$SUBMISSION_ZIP" \
        "$OUTDIR/report/$REPORT_PDF" \
        "$SCRIPT"
}

main() {
    require_root
    check_tools

    echo "=== Vulnerability Scanner ==="
    read -p "Enter target network (e.g. 192.168.84.0/24): " NET
    read -p "Enter output folder name: " NAME

    OUTDIR="${NAME}_$(date +%Y%m%d_%H%M%S)"
    SCRIPT="$(basename "$0")"

    create_dirs
    run_nmap_scan
    extract_csv
    run_vuln_scripts
    run_hydra_per_host
    create_summary
    create_pdf
    package_submission

    echo "[+] DONE! Results stored in: $OUTDIR"
}

main "$@"
