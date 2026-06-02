# Allowing Access to Local IPs

CC:T blocks local/private IP addresses by default. To allow access (e.g., for a local Gitea or HTTP server):

## Minecraft 1.13+, CC:T 1.87.0+ (current)

**File:** `serverconfig/computercraft-server.toml` (in world folder)

In `[[http.rules]]`, the `host = "$private"` deny rule blocks all private IPs (127.x, 10.x, 172.16.x, 192.168.x).

**To allow a specific private host:** Add an allow rule for that IP **before** the `$private` deny rule:
```toml
[[http.rules]]
    host = "10.10.0.10"
    port = 30008
    action = "allow"
[[http.rules]]
    host = "$private"
    action = "deny"
```

**To allow all private IPs:** Remove the `$private` deny rule entirely.

## Minecraft 1.13+, CC:T 1.86.2 and earlier

**File:** `.minecraft/config/computercraft-common.toml`

Change `blacklist = [...]` to `blacklist = []`.

## Minecraft 1.12.2 and earlier

**File:** `config/ComputerCraft.cfg`

Clear `S:blocked_domains <>`.

## After Changes
Save and restart the server.
