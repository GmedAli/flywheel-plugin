---
description: Security audit and hardening — OWASP scanning, dependency CVE checks, secrets detection, and patch generation
---

# Security Harden Workflow

> **Persona active:** `fw-security-auditor` — offensive-minded OWASP specialist. Thinks like an attacker. Prioritises findings by exploitability × impact. Every finding comes with evidence and a concrete patch.

This command runs a structured 5-phase security audit to identify vulnerabilities, check dependencies for CVEs, detect leaked secrets, and generate hardened patches. Claude orchestrates specialized agents at each phase. **No code is changed until you approve the fixes.**

---

## Step 0: Parse Input & Detect Scope

Parse the user's input:
- **Scope specification**: the full text after `/fw:harden`
- If no description provided, ask: *"What would you like to harden? Options: a specific file/module, the full project, or a recent PR branch. Example: 'src/auth/', 'the whole project', '#142'"*

**Detect scope** from the input:

| Scope | Detection | Effect |
|-------|-----------|--------|
| `file` | Single file path provided | Phases 1-4 on that file only |
| `module` | Directory path or module name | Phases 1-4 on that directory |
| `project` | "project", "all", "everything", or no path | Full codebase scan |
| `branch` | PR number or branch name | Only scan files changed on the branch |

**Detect stack** automatically:
- Check for `package.json` → Node.js/JavaScript/TypeScript
- Check for `requirements.txt` / `pyproject.toml` → Python
- Check for `go.mod` → Go
- Check for `Cargo.toml` → Rust
- Check for `pom.xml` / `build.gradle` → Java
- Note the frameworks in use (Express, Django, React, etc.)

Show the classification:
```
🛡️ Security Audit: <scope description>
🔧 Stack detected: <language + framework>
📐 Scope: PROJECT — full codebase scan
```

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/harden/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Scope description
- Stack detected
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory
- Files in scope (list or count)

---

## Phase 1: Static Analysis — Code Vulnerabilities 🔍

> *`fw-security-auditor` persona performs OWASP Top 10 + language-specific vulnerability scan*

**Goal:** Find vulnerabilities in the source code itself — injection, auth flaws, misconfigurations.

**Primary path — invoke `fw-security-auditor` persona directly:**
```
Task(fw-security-auditor): Perform a full security audit of the following scope. Produce a complete Security Audit Report with findings prioritised by severity. Every finding must include: OWASP category, file:line, evidence, attack scenario, and proposed patch.

SCOPE: <SCOPE_DESCRIPTION>
STACK: <DETECTED_STACK>
FILES: <FILES_IN_SCOPE>
```

Save output to `$SESSION_DIR/01-code-audit.md`.

**Fallback — if fw-security-auditor persona not installed, run Codex:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a security auditor. Perform a thorough static security analysis of the following codebase.

SCOPE: <SCOPE_DESCRIPTION>
STACK: <DETECTED_STACK>

Scan for ALL of the following categories:

### OWASP Top 10 (2021)
1. **A01 — Broken Access Control**: Missing auth checks, IDOR, privilege escalation, CORS misconfig
2. **A02 — Cryptographic Failures**: Weak algorithms, hardcoded keys, missing encryption, insecure hashing
3. **A03 — Injection**: SQL injection, NoSQL injection, command injection, LDAP injection, XSS
4. **A04 — Insecure Design**: Missing rate limiting, trust boundary violations, business logic flaws
5. **A05 — Security Misconfiguration**: Debug mode in prod, default credentials, verbose errors, missing headers
6. **A06 — Vulnerable Components**: (covered in Phase 2 — skip here)
7. **A07 — Auth Failures**: Weak passwords allowed, missing brute-force protection, session fixation
8. **A08 — Data Integrity Failures**: Insecure deserialization, unsigned updates, CI/CD vulnerabilities
9. **A09 — Logging Failures**: Missing audit logs, sensitive data in logs, no alerting on failures
10. **A10 — SSRF**: Unvalidated URLs, internal service access, cloud metadata exposure

### Language-Specific Checks
- **JavaScript/TypeScript**: eval(), prototype pollution, regex DoS, unsafe innerHTML, missing CSP
- **Python**: pickle deserialization, unsafe yaml.load, subprocess shell=True, format string injection
- **Go**: unchecked errors, race conditions, unsafe pointer usage
- **Java**: XML external entities, insecure random, object deserialization

For EACH finding, report:
| Severity | OWASP Category | File:Line | Description | Evidence |
|----------|---------------|-----------|-------------|----------|
| CRITICAL/HIGH/MEDIUM/LOW | A01-A10 | path:line | What's wrong | The vulnerable code |

Be thorough but eliminate false positives. Only report genuine vulnerabilities with evidence." <FILES_IN_SCOPE>
```

Save output to `$SESSION_DIR/01-code-audit.md`.

Print:
```
✅ Phase 1 Complete — Code Vulnerability Scan
   Critical: <N> findings
   High: <N> findings
   Medium: <N> findings
   Low: <N> findings
```

---

## Phase 2: Dependency Audit — CVE & Supply Chain 📦

> *Gemini cross-references dependencies against known vulnerability databases*

**Goal:** Check all dependencies for known CVEs, outdated versions with security patches, and supply chain risks.

### 2a — Collect dependency information (Claude)

You (Claude) gather dependency data:
1. Read the lockfile (package-lock.json, yarn.lock, poetry.lock, go.sum, Cargo.lock, etc.)
2. Read the dependency manifest (package.json, requirements.txt, go.mod, Cargo.toml, etc.)
3. List all direct and notable transitive dependencies with versions

Save to `$SESSION_DIR/02-dependencies.md`.

### 2b — CVE cross-reference (Gemini)

**Context7 pre-enrichment** — before dispatching to Gemini, gather official security documentation for the top packages of concern:

1. From the dependency list in Phase 2a, identify the top 3 packages most relevant to the audit scope (prioritise packages with known risk or those central to the application)
2. For each, call `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` with query: "Security best practices, known vulnerabilities, and secure configuration for <package>"
3. If Context7 returns results, prepend them to the Gemini prompt as `OFFICIAL DOCUMENTATION CONTEXT`
4. If Context7 fails or returns nothing, skip silently and proceed without enrichment

**Run Gemini:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "gemini" "OFFICIAL DOCUMENTATION CONTEXT (via Context7):
<Context7 security docs, or omit this section if none>

---

You are a supply chain security analyst. Check the following dependencies for known vulnerabilities.

DEPENDENCIES:
<contents of 02-dependencies.md>

STACK: <DETECTED_STACK>

For each dependency, check:
1. **Known CVEs** — any published CVEs for this version? Include CVE ID and severity (CVSS score)
2. **Security advisories** — any GitHub Security Advisories or npm/PyPI advisories?
3. **Outdated with security patches** — is there a newer version that fixes security issues?
4. **Deprecated or unmaintained** — is the package abandoned or deprecated?
5. **Supply chain risk** — any known typosquatting, compromised maintainer, or malicious version incidents?

Format as:
| Package | Version | Issue | Severity | CVE/Advisory | Fix Version |
|---------|---------|-------|----------|-------------|-------------|

Only report genuine security issues. Skip packages with no known vulnerabilities."
```

Save output to `$SESSION_DIR/02-cve-audit.md`.

Print:
```
✅ Phase 2 Complete — Dependency Audit
   Vulnerable packages: <N>
   Critical CVEs: <N>
   Outdated (security patches available): <N>
```

---

## Phase 3: Secrets & Configuration Scan 🔑

> *Claude scans for leaked secrets, misconfigurations, and unsafe defaults*

**Goal:** Find hardcoded secrets, leaked credentials, and insecure configuration patterns.

You (Claude) scan the codebase for:

### Secrets Detection
- **API keys**: grep for patterns like `AKIA[0-9A-Z]{16}`, `sk-[a-zA-Z0-9]{48}`, `ghp_[a-zA-Z0-9]{36}`
- **Passwords**: grep for `password\s*=\s*["']`, `secret\s*=\s*["']`, `token\s*=\s*["']`
- **Connection strings**: database URLs with credentials, Redis URLs with passwords
- **Private keys**: `-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----`
- **JWT secrets**: hardcoded signing keys
- **Environment leaks**: `.env` files committed, env vars in source code

### Configuration Audit
- **CORS**: Is it set to `*` in production?
- **HTTPS**: Are there hardcoded `http://` URLs for APIs?
- **Debug mode**: Is debug/development mode enabled in config?
- **Default ports**: Are admin panels on default ports without auth?
- **Error exposure**: Are stack traces or internal errors returned to clients?
- **.gitignore**: Are sensitive files properly ignored?

### File Permission Checks
- Are there executable scripts with overly permissive access?
- Are configuration files with secrets readable by all?

Save findings to `$SESSION_DIR/03-secrets-audit.md`.

Print:
```
✅ Phase 3 Complete — Secrets & Configuration
   Leaked secrets: <N> found
   Misconfigurations: <N> found
   .gitignore gaps: <N> found
```

---

## Phase 4: Triage & Patch Generation 📋

> *Claude triages all findings, then Codex generates patches for approved fixes*

**Goal:** Prioritise findings, present a clear report, and generate ready-to-apply patches.

### 4a — Triage (Claude)

You (Claude) consolidate all findings from Phases 1-3 and:
1. **Deduplicate** — remove findings that overlap across phases
2. **Validate** — eliminate false positives based on your codebase understanding
3. **Prioritise** — rank by: exploitability × impact × exposure
4. **Categorise** — group by severity level

Display the consolidated security report to the user:

```markdown
# 🛡️ Security Audit Report: <PROJECT_NAME>

**Date**: <CURRENT_DATE>
**Scope**: <SCOPE>
**Stack**: <STACK>
**Session**: <SESSION_DIR>

---

## Executive Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | <N> |
| 🟠 High | <N> |
| 🟡 Medium | <N> |
| 🟢 Low | <N> |

**Overall Risk Level**: <CRITICAL / HIGH / MODERATE / LOW>

---

## 🔴 Critical Findings

### Finding C1: <Title>
- **Category**: <OWASP A0X / CVE / Secret Leak>
- **Location**: `<file:line>`
- **Description**: <What's vulnerable>
- **Impact**: <What an attacker could do>
- **Evidence**: <The vulnerable code or config>

### Finding C2: ...

---

## 🟠 High Findings
<Same format as Critical>

## 🟡 Medium Findings
<Same format, condensed>

## 🟢 Low Findings
<Brief list format>

---

## Dependency Vulnerabilities
| Package | CVE | Severity | Fix |
|---------|-----|----------|-----|
| ... | CVE-XXXX-XXXXX | HIGH | Upgrade to x.y.z |

---

## Secrets Found
| Type | File | Status |
|------|------|--------|
| API Key | config.js:12 | 🔴 Hardcoded |
| .env | .env.local | 🟡 Not in .gitignore |
```

Save report to `$SESSION_DIR/04-report.md`.

### 4b — User Gate

Ask:
```
🛡️ Security audit complete. How would you like to proceed?

  [patch all]    — generate fixes for all findings
  [patch critical] — generate fixes for critical + high only
  [accept]       — acknowledge the report (no code changes)
  [delegate]     — hand off fixes to /fw:implement
```

- **patch all** or **patch critical** → continue to 4c
- **accept** → Print "Security audit saved to `$SESSION_DIR`." and stop
- **delegate** → Auto-populate `/fw:implement` with a hardening task description from the report

### 4c — Patch Generation (Codex)

Run Codex to generate patches:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a security engineer. Generate production-ready patches for the following security findings.

FINDINGS TO FIX:
<selected findings from the report>

CODEBASE CONTEXT:
<relevant file contents>

For each finding:
1. Show the EXACT fix — old code → new code
2. Explain WHY this fix resolves the vulnerability
3. Note any side effects or breaking changes
4. Follow existing code patterns and style

Do NOT introduce new dependencies unless absolutely necessary.
Do NOT change functionality — only fix the security issues.
Apply the patches to the affected files." <AFFECTED_FILES>
```

Save patches to `$SESSION_DIR/04-patches.md`.

Print:
```
✅ Phase 4 Complete — Patches Generated
   Patches: <N> fixes ready
   Files affected: <N>
```

### 4d — Validate patches

After patches are applied:
1. Run linter to check for syntax issues
2. Run type checker if applicable
3. Run test suite to ensure no regressions

Report:
```
🛡️ Patch Validation:
   Lint:  ✅ passed | ❌ <N> errors
   Types: ✅ passed | ❌ <N> errors
   Tests: ✅ <N>/<N> passed | ❌ <N> failures
```

If validation fails, offer to fix or rollback (same pattern as `/fw:migrate`).

---

## Final Summary

You (Claude) produce the final summary:

```markdown
# ✅ Security Hardening Complete: <PROJECT_NAME>

## What Was Done
<2-3 sentence summary>

## Findings & Fixes
| Severity | Found | Fixed | Remaining |
|----------|-------|-------|-----------|
| Critical | <N> | <N> | <N> |
| High | <N> | <N> | <N> |
| Medium | <N> | <N> | <N> |
| Low | <N> | <N> | <N> |

## Remaining Manual Actions
<Any findings that require manual intervention:
- Rotating leaked secrets/API keys
- Updating environment variables in production
- Configuring WAF rules or rate limiting
- Updating CI/CD security checks>

## Suggested Next Steps
- Rotate any exposed secrets immediately
- Run `/fw:test` to add security-focused test cases
- Run `/fw:review` before merging security patches
- Consider adding a pre-commit hook for secrets detection
- Schedule periodic re-runs of `/fw:harden`

## Session Files
All phase outputs saved to: <SESSION_DIR>
```

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phases 1 and 4c with a note that analysis depth may be reduced
- **Gemini not available**: Skip Phase 2b CVE cross-reference, note the gap in dependency audit
- **No vulnerabilities found**: Report clean bill of health — still save session for audit trail
- **User cancels at any phase**: Save session state and print the session directory path
- **Patch causes test failures**: Offer fix → rollback options, never auto-continue past failures

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_HARDEN_DIR` | `~/.flywheel/projects/<project>/harden` | Where security audit session files are saved |
