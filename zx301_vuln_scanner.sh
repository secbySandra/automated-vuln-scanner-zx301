#!/bin/bash
# ============================================================
# ZX301 Automated Vulnerability Scanner
# Author: secbySandra
# Description: Automated vulnerability assessment pipeline
# Environment: Kali Linux
# ============================================================

set -e

REPORT_NAME="ZX301_Vulnerability_Scanner_Report.pdf"
SUBMISSION_ZIP="ZX301_Scan_Results.zip"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERROR] This script must be executed as root."
        exit 1
    fi
}

check_dependencies() {
    local tools=(nmap hydra searchsploit pandoc zip)
    echo "[*] Checking required tools..."
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "[ERROR] Missing dependency: $tool"
            exit 1
        fi
    done
}

create_structure() {
    mkdir -p "$OUTDIR"/{nmap,credentials,report}
}

run_nmap() {
    echo "[*] Running full Nmap scan..."
    nmap -sS -sV -O -p- -oA "$OUTDIR/nmap/full_scan" "$TARGET"
}

extract_open_services() {
    echo "[*] Extracting open services..."
    awk -F'[ /]' '/open/{
        printf "%s,%s,%s,%s,%s\n",$2,$1,$5,$4,$6
    }' "$OUTDIR/nmap/full_scan.gnmap" \
    > "$OUTDIR/report/open_services.csv"
}

run_vulnerability_scan() {
    echo "[*] Running NSE vulnerability scripts..."
    nmap --script vuln -oA "$OUTDIR/nmap/nse_vuln" "$TARGET"

    echo "[*] Mapping potential exploits..."
    searchsploit --nmap "$OUTDIR/nmap/nse_vuln.xml" \
        > "$OUTDIR/report/exploits.txt"
}

run_credential_testing() {
    echo "[*] Checking for SSH services..."
    grep "22/open" "$OUTDIR/nmap/full_scan.gnmap" | awk '{print $2}' \
        > "$OUTDIR/ssh_targets.txt" || true

    if [[ -s "$OUTDIR/ssh_targets.txt" ]]; then
        while read -r host; do
            echo "[*] Running Hydra against $host"
            hydra -L /usr/share/wordlists/metasploit/default_users.txt \
                  -P /usr/share/wordlists/rockyou.txt \
                  ssh://"$host" \
                  -o "$OUTDIR/credentials/hydra_$host.txt"
        done < "$OUTDIR/ssh_targets.txt"
    else
        echo "[*] No SSH services detected."
    fi
}

generate_summary() {
    echo "[*] Generating summary report..."

    {
        echo "ZX301 Vulnerability Assessment Report"
        echo "====================================="
        echo "Target: $TARGET"
        echo "Scan Date: $(date)"
        echo ""

        echo "Open Services:"
        echo "--------------"
        cat "$OUTDIR/report/open_services.csv"
        echo ""

        echo "Potential Exploits:"
        echo "-------------------"
        sed -n '1,200p' "$OUTDIR/report/exploits.txt"
    } > "$OUTDIR/report/summary.txt"
}

generate_pdf() {
    echo "[*] Creating PDF report..."
    pandoc "$OUTDIR/report/summary.txt" \
        -o "$OUTDIR/report/$REPORT_NAME"
}

package_results() {
    echo "[*] Packaging results..."
    zip -r "$OUTDIR/$SUBMISSION_ZIP" "$OUTDIR/report"
}

main() {
    require_root
    check_dependencies

    echo "=== ZX301 Automated Vulnerability Scanner ==="
    read -p "Enter target network (e.g. 192.168.1.0/24): " TARGET
    read -p "Enter output directory name: " NAME

    OUTDIR="${NAME}_$(date +%Y%m%d_%H%M%S)"

    create_structure
    run_nmap
    extract_open_services
    run_vulnerability_scan
    run_credential_testing
    generate_summary
    generate_pdf
    package_results

    echo "[+] Scan completed. Results saved in: $OUTDIR"
}

main "$@"
