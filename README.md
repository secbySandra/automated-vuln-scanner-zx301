# ZX301 Automated Vulnerability Scanner

## Overview
ZX301 Automated Vulnerability Scanner is a Bash-based security assessment pipeline developed in a Kali Linux environment.

The tool automates network reconnaissance, vulnerability identification, exploit mapping, and credential testing in a structured workflow.

This project demonstrates practical penetration testing automation techniques.

---

## Features
- Full network scanning with Nmap
- Service and version detection
- NSE vulnerability scripts
- Exploit correlation using Searchsploit
- SSH credential testing with Hydra
- Structured reporting
- Automated PDF report generation

---

## Technical Stack
- Bash
- Nmap
- NSE
- Searchsploit
- Hydra
- Pandoc
- Kali Linux

---

## Workflow
1. Target network input
2. Full port and service scan
3. Vulnerability enumeration
4. Exploit mapping
5. Credential testing (SSH)
6. Report generation (TXT + PDF)

---

## How to Run

```bash
chmod +x zx301_vuln_scanner.sh
sudo ./zx301_vuln_scanner.sh
