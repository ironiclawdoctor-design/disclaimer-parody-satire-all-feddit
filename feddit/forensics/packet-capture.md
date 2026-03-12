# 📡 Packet Capture — Network Forensics for the Comfortably Bored

> *Every packet tells a story. Most of those stories are incredibly dull. That's how you know your network is healthy.*

**Author:** Nemesis · `nemesis@feddit.parody`
**Classification:** Educational / Forensics / 😴 Boring
**Last Updated:** 2026-03-12

---

## The Philosophy

Network forensics is wiretapping your own infrastructure — legally, ethically, and with the enthusiasm of someone watching paint dry. You're not a spy. You're an auditor with tcpdump.

The exciting part was the breach. Your job is to read the packets afterward and say "yep, should've had egress filtering" while sipping coffee.

---

## Part 1: Capturing Packets

### 1.0 — tcpdump (The Boring Standard)

`tcpdump` has been around since 1988. It is older than most of the people reading this. It is also better at its job than most of the people reading this.

```bash
# === BASIC CAPTURES ===

# Capture everything on eth0 (don't do this in production for long)
tcpdump -i eth0

# Capture with human-readable timestamps and don't resolve hostnames (faster)
tcpdump -i eth0 -tttt -n

# Capture and save to file (pcap format — the lingua franca)
tcpdump -i eth0 -w /tmp/capture-$(date +%Y%m%d-%H%M%S).pcap

# Read a saved capture
tcpdump -r /tmp/capture.pcap

# Capture only N packets (useful for sampling)
tcpdump -i eth0 -c 1000 -w /tmp/sample.pcap


# === FILTERED CAPTURES ===

# Only traffic to/from a specific host
tcpdump -i eth0 host 203.0.113.42

# Only SSH traffic
tcpdump -i eth0 port 22

# Only HTTP/HTTPS traffic
tcpdump -i eth0 port 80 or port 443

# Only DNS traffic
tcpdump -i eth0 port 53

# Traffic to a specific subnet
tcpdump -i eth0 net 10.0.0.0/24

# Only SYN packets (connection attempts)
tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn) != 0 and tcp[tcpflags] & (tcp-ack) == 0'

# Only RST packets (connection resets — something went wrong or was blocked)
tcpdump -i eth0 'tcp[tcpflags] & (tcp-rst) != 0'

# ICMP only (ping, traceroute, and network recon)
tcpdump -i eth0 icmp


# === FORENSIC CAPTURES ===

# Full packet contents (not just headers)
tcpdump -i eth0 -X -s 0 -w /tmp/full-capture.pcap

# Capture with ring buffer (5 files, 100MB each — rotates automatically)
tcpdump -i eth0 -w /tmp/rolling-%Y%m%d%H%M%S.pcap -G 3600 -W 5 -C 100

# Non-standard ports (potential C2 channels)
tcpdump -i eth0 'not (port 22 or port 80 or port 443 or port 53 or port 123)' -w /tmp/unusual.pcap
```

### 1.1 — tshark (Wireshark's Boring CLI Cousin)

When you need Wireshark's protocol dissection but hate GUIs (or you're on a headless server like a normal person).

```bash
# Capture with protocol decoding
tshark -i eth0 -c 100

# HTTP requests only
tshark -i eth0 -Y "http.request" -T fields -e ip.src -e http.host -e http.request.uri

# DNS queries
tshark -i eth0 -Y "dns.qr == 0" -T fields -e ip.src -e dns.qry.name

# TLS handshakes (see who's connecting where, even though traffic is encrypted)
tshark -i eth0 -Y "tls.handshake.type == 1" -T fields -e ip.src -e ip.dst -e tls.handshake.extensions_server_name

# Read pcap and extract HTTP objects
tshark -r capture.pcap --export-objects http,/tmp/extracted-objects/

# Statistics — protocol hierarchy
tshark -r capture.pcap -q -z io,phs

# Statistics — conversations (who talked to whom)
tshark -r capture.pcap -q -z conv,tcp

# Statistics — endpoints (traffic volume by host)
tshark -r capture.pcap -q -z endpoints,ip
```

### 1.2 — Wireshark (The GUI for When You Need Pictures)

For the handful of times a visual protocol dissection actually helps:

**Essential display filters:**
```
# HTTP traffic
http

# DNS queries
dns.qr == 0

# Failed TCP connections (SYN without SYN-ACK)
tcp.analysis.retransmission

# TLS certificate info
tls.handshake.certificate

# Specific IP
ip.addr == 203.0.113.42

# Specific conversation
ip.addr == 203.0.113.42 && ip.addr == 10.0.0.5

# Large packets (potential data exfil)
frame.len > 1400

# HTTP POST requests (data submission)
http.request.method == "POST"

# Non-standard DNS (tunneling indicator)
dns && frame.len > 200

# TCP errors and anomalies
tcp.analysis.flags
```

**Wireshark pro tips for forensics:**
1. **Follow TCP Stream** — Right-click a packet → Follow → TCP Stream. See the full conversation.
2. **Export HTTP Objects** — File → Export Objects → HTTP. Extract downloaded files.
3. **Protocol Hierarchy** — Statistics → Protocol Hierarchy. See what protocols are in your capture.
4. **Conversations** — Statistics → Conversations. See who talked to whom and how much.
5. **I/O Graph** — Statistics → I/O Graph. See traffic patterns over time (spikes = interesting).

---

## Part 2: Reading Packet Captures (The Boring Art)

### 2.0 — TCP Handshake Analysis

Every TCP connection starts with the 3-way handshake. When it doesn't complete, something's wrong (or someone's scanning).

```
Normal handshake:
  Client → Server:  SYN
  Server → Client:  SYN-ACK
  Client → Server:  ACK
  [connection established]

Port scan (SYN scan):
  Client → Server:  SYN
  Server → Client:  SYN-ACK  (port is open)
  Client → Server:  RST      (scanner doesn't complete — just wanted to know if port was open)

Blocked port:
  Client → Server:  SYN
  [no response or ICMP unreachable]

Refused connection:
  Client → Server:  SYN
  Server → Client:  RST      (port is closed)
```

**Detection:**
```bash
# Count SYN-only packets per source (port scanning indicator)
tcpdump -r capture.pcap 'tcp[tcpflags] == tcp-syn' -n | \
  awk '{print $3}' | cut -d. -f1-4 | sort | uniq -c | sort -rn | head -10
```

**Boring counter:** Default-deny firewall. The scanner gets nothing back. They get bored. They leave.

### 2.1 — DNS Analysis

DNS is the most abused protocol on the internet because everyone leaves port 53 open. Every exfil technique, every C2 channel, every tunnel eventually touches DNS.

**Normal DNS:**
```
Query:  A record for www.example.com → 93.184.216.34
Query:  AAAA record for www.example.com → 2606:2800:220:1:248:1893:25c8:1946
```

**Suspicious DNS:**
```
# Very long subdomain (DNS tunneling)
Query:  TXT record for aGVsbG8gd29ybGQgdGhpcyBpcyBkYXRhIGV4ZmlsdHJhdGlvbg.evil.com

# Many unique subdomain queries to same domain (C2 beaconing)
Query:  A record for session-abc123.evil.com
Query:  A record for session-abc124.evil.com
Query:  A record for session-abc125.evil.com

# TXT record queries (often used for data exfil/C2)
Query:  TXT record for cmd.evil.com → "d2hvYW1p"  (base64 encoded command)
```

**Detection:**
```bash
# Long DNS queries (tunneling indicator — normal queries are short)
tshark -r capture.pcap -Y "dns.qr == 0" -T fields -e dns.qry.name | \
  awk '{if(length($0) > 50) print length($0), $0}' | sort -rn

# Many unique subdomains for same parent domain (C2 beaconing)
tshark -r capture.pcap -Y "dns.qr == 0" -T fields -e dns.qry.name | \
  awk -F. '{print $(NF-1)"."$NF}' | sort | uniq -c | sort -rn | head -10

# TXT record queries (unusual for normal browsing)
tshark -r capture.pcap -Y "dns.qry.type == 16" -T fields -e ip.src -e dns.qry.name

# DNS to non-standard resolvers (your hosts should use YOUR DNS server)
tshark -r capture.pcap -Y "dns && !(ip.dst == 10.0.0.1)" -T fields -e ip.src -e ip.dst | sort -u
```

**Boring counter:** Force all DNS through your resolver (firewall rule blocking port 53 outbound except to your DNS). Monitor query logs. `Pi-hole` or `AdGuard Home` does this while also blocking ads. Two birds, one boring stone.

### 2.2 — HTTP/HTTPS Analysis

```bash
# HTTP request/response pairs
tshark -r capture.pcap -Y "http" -T fields \
  -e frame.time -e ip.src -e ip.dst -e http.request.method \
  -e http.host -e http.request.uri -e http.response.code

# Find file downloads
tshark -r capture.pcap -Y "http.content_type contains \"application\"" \
  -T fields -e ip.dst -e http.content_type -e http.request.uri

# POST data (potential credential submission)
tshark -r capture.pcap -Y "http.request.method == POST" \
  -T fields -e ip.src -e http.host -e http.request.uri -e http.file_data

# TLS SNI (Server Name Indication — see HTTPS destinations)
tshark -r capture.pcap -Y "tls.handshake.extensions_server_name" \
  -T fields -e ip.src -e tls.handshake.extensions_server_name | sort | uniq -c | sort -rn
```

### 2.3 — Anomaly Patterns to Watch For

| Anomaly | What It Looks Like | What It Might Mean |
|---|---|---|
| **Beaconing** | Regular interval connections to same host (e.g., every 60s) | C2 channel |
| **DNS tunneling** | Very long DNS queries, high TXT record volume | Data exfiltration |
| **Port hopping** | Same source, many different destination ports | Port scanning |
| **Large uploads** | Outbound traffic volume >> inbound | Data exfiltration |
| **Protocol mismatch** | HTTP on port 4444, SSH on port 80 | Tunnel/evasion |
| **After-hours traffic** | Network activity at 3 AM from workstation | Compromised host |
| **New destinations** | Connections to IPs/domains not seen before | New C2 or legit? Check. |
| **Certificate anomalies** | Self-signed certs, expired certs, mismatched names | MitM or lazy admin |

---

## Part 3: Forensic Pcap Analysis Workflow

### The Nemesis Packet Review Protocol

```
Step 0: SCOPE       — Define the time window and hosts of interest
Step 1: OVERVIEW    — Protocol hierarchy, top talkers, conversation list
Step 2: DNS REVIEW  — What domains were queried? Any tunneling indicators?
Step 3: CONNECTIONS — Who connected to whom? Any unusual ports/protocols?
Step 4: CONTENT     — For unencrypted traffic: what was transferred?
Step 5: TIMELINE    — Build chronological event sequence
Step 6: CORRELATE   — Match findings with log analysis (see log-analysis.md)
Step 7: DOCUMENT    — Report template (see below)
```

### Quick Start Script

```bash
#!/bin/bash
# pcap-quick-analysis.sh — First-pass analysis of a capture file
# Usage: ./pcap-quick-analysis.sh capture.pcap

PCAP="$1"
if [ -z "$PCAP" ]; then echo "Usage: $0 <pcap-file>"; exit 1; fi

echo "=== Nemesis Pcap Quick Analysis ==="
echo "File: $PCAP"
echo "Size: $(ls -lh "$PCAP" | awk '{print $5}')"
echo ""

echo "--- Capture Info ---"
capinfos "$PCAP" 2>/dev/null || tshark -r "$PCAP" -q -z io,stat,0
echo ""

echo "--- Protocol Hierarchy ---"
tshark -r "$PCAP" -q -z io,phs
echo ""

echo "--- Top 10 Talkers (by packets) ---"
tshark -r "$PCAP" -q -z endpoints,ip | head -20
echo ""

echo "--- Top 10 Conversations ---"
tshark -r "$PCAP" -q -z conv,tcp | head -20
echo ""

echo "--- DNS Queries (unique domains) ---"
tshark -r "$PCAP" -Y "dns.qr == 0" -T fields -e dns.qry.name 2>/dev/null | sort -u | head -20
echo ""

echo "--- HTTP Hosts ---"
tshark -r "$PCAP" -Y "http.request" -T fields -e http.host 2>/dev/null | sort | uniq -c | sort -rn | head -10
echo ""

echo "--- TLS SNI (HTTPS destinations) ---"
tshark -r "$PCAP" -Y "tls.handshake.extensions_server_name" -T fields \
  -e tls.handshake.extensions_server_name 2>/dev/null | sort | uniq -c | sort -rn | head -10
echo ""

echo "--- Potential Anomalies ---"
echo "Long DNS queries (>50 chars):"
tshark -r "$PCAP" -Y "dns.qr == 0" -T fields -e dns.qry.name 2>/dev/null | \
  awk '{if(length($0) > 50) print "  ⚠️", $0}'
echo "Non-standard ports:"
tshark -r "$PCAP" -T fields -e ip.src -e tcp.dstport 2>/dev/null | \
  awk '$2 != 22 && $2 != 80 && $2 != 443 && $2 != 53 && $2 != 123 && $2 != "" {print "  ⚠️", $1, "→ port", $2}' | \
  sort -u | head -10
echo ""

echo "=== Analysis complete. Be boring. ==="
```

---

## Part 4: Practical Scenarios

### Scenario: "Something is beaconing"

```bash
# Find periodic connections (beaconing detection)
# Extract timestamps for connections to each unique destination
tshark -r capture.pcap -Y "tcp.flags.syn == 1 && tcp.flags.ack == 0" \
  -T fields -e frame.time_epoch -e ip.dst | sort -k2 | \
  awk '{
    if($2 == prev_dst) {
      delta = $1 - prev_time
      if(delta > 0 && delta < 300) printf "%.0fs interval to %s\n", delta, $2
    }
    prev_dst = $2
    prev_time = $1
  }' | sort | uniq -c | sort -rn | head -10

# If you see consistent intervals (e.g., "60s interval to 198.51.100.99" appearing 200 times)
# → That's beaconing. Investigate that destination.
```

### Scenario: "Is data leaving the building?"

```bash
# Outbound traffic volume by destination
tshark -r capture.pcap -T fields -e ip.dst -e frame.len | \
  awk '{bytes[$1] += $2} END {for(ip in bytes) printf "%s\t%d bytes\t%.2f MB\n", ip, bytes[ip], bytes[ip]/1048576}' | \
  sort -k2 -rn | head -10

# Compare inbound vs outbound ratios (normal browsing: more inbound)
tshark -r capture.pcap -q -z io,stat,0,"ip.src == 10.0.0.0/8","ip.dst == 10.0.0.0/8"
```

### Scenario: "What was in that unencrypted connection?"

```bash
# Extract cleartext credentials from HTTP POST (why is this still unencrypted??)
tshark -r capture.pcap -Y "http.request.method == POST" \
  -T fields -e http.host -e http.request.uri -e http.file_data | head -5

# Follow a specific TCP stream
tshark -r capture.pcap -z "follow,tcp,ascii,0" -q

# Extract all files from HTTP traffic
tshark -r capture.pcap --export-objects http,/tmp/extracted/ 2>/dev/null
ls -la /tmp/extracted/
```

**Boring counter to all of the above:** HTTPS everywhere. Let's Encrypt. Free. Automated. There is no excuse for cleartext HTTP in 2026.

---

## Part 5: Evidence Handling (The Legal Boring Part)

### Chain of Custody for Pcap Files

```bash
# When you capture evidence, hash it immediately
sha256sum capture.pcap > capture.pcap.sha256

# Document the capture metadata
echo "Captured by: $(whoami)" >> capture.metadata
echo "Captured on: $(hostname)" >> capture.metadata
echo "Captured at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> capture.metadata
echo "Interface: eth0" >> capture.metadata
echo "Filter: [whatever filter you used]" >> capture.metadata
echo "SHA256: $(cat capture.pcap.sha256)" >> capture.metadata

# Work on a COPY, never the original
cp capture.pcap capture-working-copy.pcap

# Store original in read-only location
chmod 444 capture.pcap
mv capture.pcap /evidence/case-$(date +%Y%m%d)/
```

This seems tediously legalistic. It is. That's why it works in court. Be boring. Be admissible.

---

> *In network forensics, the boring analyst sees everything. The exciting analyst sees only what they expect. Be the boring one.*
>
> — Nemesis, staring at hex dumps, feeling nothing
