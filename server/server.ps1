<#
  DocuRoute prototype backend — a real (if minimal) server process with its
  own temporary database, replacing the browser-only localStorage mock.

  Zero install: uses only what ships with Windows PowerShell (System.Net.HttpListener
  for the HTTP server, a plain JSON file as the database). Restart-safe — data
  persists in db.json between runs; delete db.json (or POST /api/reset) to wipe it.

  Run:  powershell -ExecutionPolicy Bypass -File server.ps1
  Then open ../index.html in a browser — it talks to http://localhost:8787/api.
#>

param(
  [int]$Port = 8787
)

$ErrorActionPreference = "Stop"
$DbPath = Join-Path $PSScriptRoot "db.json"

$ROUTES = @{
  waiver     = @("Dean's Office","Registrar")
  adjustment = @("Registrar")
  clearance  = @("Accounting","Dean's Office","Registrar")
}

$Script:State = $null

function ConvertTo-Hashtable {
  param($InputObject)
  if ($null -eq $InputObject) { return $null }
  if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
    $arr = @()
    foreach ($item in $InputObject) { $arr += ,(ConvertTo-Hashtable $item) }
    return ,$arr
  } elseif ($InputObject -is [PSCustomObject]) {
    $hash = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) {
      $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value
    }
    return $hash
  } else {
    return $InputObject
  }
}

function Add-Log {
  param($req, [string]$text)
  $entry = [ordered]@{ ts = (Get-Date).ToUniversalTime().ToString("o"); text = $text }
  $req.log = @($req.log) + $entry
}

function New-RequestId {
  $id = "DR-2026-" + ($Script:State.seq).ToString("0000")
  $Script:State.seq = $Script:State.seq + 1
  return $id
}

function Apply-Plan {
  param($req, [int]$confidence, [string]$plan)
  $req.status = "review"
  Add-Log $req "AI Processing Layer: image rectified, OCR extracted, layout-aware classification run."
  $req.confidence = $confidence
  if ($confidence -lt 70) {
    $req.status = "unverified"
    Add-Log $req "Confidence $confidence% is below the 70% threshold - flagged 'Unverified' and sent to the intake clerk queue."
    if ($plan -eq "unverified") { return }
  } else {
    $req.status = "routed"
    Add-Log $req "Confidence $confidence% - deterministic routing table assigned this to $($req.route[0]). QR sticker printed, digital twin archived."
    if ($plan -eq "routed") { return }
  }
  if ($plan -eq "progress" -or $plan -eq "completed") {
    $req.status = "progress"
    Add-Log $req "$($req.route[$req.hop]) marked the request In Progress."
    if ($plan -eq "progress") { return }
  }
  if ($plan -eq "completed") {
    while ($req.hop -lt ($req.route.Count - 1)) {
      Add-Log $req "$($req.route[$req.hop]) cleared the request - forwarded to $($req.route[$req.hop + 1])."
      $req.hop = $req.hop + 1
    }
    $req.status = "completed"
    Add-Log $req "$($req.route[$req.hop]) gave final approval. Request closed."
  }
}

function New-DemoRequest {
  param($type, $student, $program, $studentNo, $fields, [int]$confidence, [string]$plan)
  $id = New-RequestId
  $req = [ordered]@{
    id = $id; type = $type; student = $student; studentNo = $studentNo; program = $program
    nationality = "Filipino"; contactNo = "09171234567"; fields = $fields
    confidence = $null; route = @($ROUTES[$type]); hop = 0; status = "submitted"; log = @()
  }
  Add-Log $req "Submitted by $student at the Registrar window."
  $Script:State.requests = @($Script:State.requests) + $req
  Apply-Plan $req $confidence $plan
}

function Reset-Demo {
  $Script:State = [ordered]@{ seq = 1; requests = @() }
  New-DemoRequest "waiver" "Aaron Peter San Pedro" "BS Information Technology / 4" "2021100234" `
    @{ quarterAY = "1Q, AY 2026-2027"; prereq = "IT101"; advanced = "IT201" } 92 "routed"
  New-DemoRequest "adjustment" "Mike Emil F. Vocal" "BS Information Technology / 4" "2021100567" `
    @{ currentSection = "IT41FA1"; newSection = "IT41FA2"; subject = "IT201" } 88 "completed"
  New-DemoRequest "clearance" "Bea Villanueva" "BS Computer Science / 3" "2022100112" `
    @{ reason = "Transferring to another program" } 61 "unverified"
  New-DemoRequest "waiver" "Carlo Dizon" "BS Information Technology / 2" "2023100845" `
    @{ quarterAY = "1Q, AY 2026-2027"; prereq = "CS201"; advanced = "CS301" } 95 "progress"
}

function Save-State {
  ($Script:State | ConvertTo-Json -Depth 20) | Out-File -FilePath $DbPath -Encoding utf8
}

function Initialize-State {
  if (Test-Path $DbPath) {
    try {
      $raw = Get-Content -Raw -Path $DbPath
      $parsed = $raw | ConvertFrom-Json
      $Script:State = ConvertTo-Hashtable $parsed
      if (-not $Script:State.accounts -or @($Script:State.accounts).Count -eq 0) {
        Seed-Accounts
        Save-State
      }
      Write-Host "Loaded existing temporary database: $DbPath ($($Script:State.requests.Count) requests, $(@($Script:State.accounts).Count) accounts)"
      return
    } catch {
      Write-Host "db.json was unreadable, reseeding. ($($_.Exception.Message))"
    }
  }
  Reset-Demo
  Seed-Accounts
  Save-State
  Write-Host "Seeded a fresh temporary database: $DbPath"
}

function Find-Request {
  param([string]$id)
  foreach ($r in $Script:State.requests) { if ($r.id -eq $id) { return $r } }
  return $null
}

function New-AccountId { return "acc-" + [guid]::NewGuid().ToString("N").Substring(0,8) }

function Find-Account {
  param([string]$id)
  foreach ($a in $Script:State.accounts) { if ($a.id -eq $id) { return $a } }
  return $null
}

function Find-AccountByUsername {
  param([string]$username)
  foreach ($a in $Script:State.accounts) { if ($a.username.ToLower() -eq $username.ToLower()) { return $a } }
  return $null
}

# Prototype-only auth: plaintext passwords, no session tokens. Good enough for a
# thesis click-through demo; not a pattern to carry into the real system (Section 3.10).
function Seed-Accounts {
  $Script:State.accounts = @(
    [ordered]@{ id="acc-student"; username="apvsanpedro@mymail.mapua.edu.ph"; password="BSIT3"; role="student"; name="Aaron Peter San Pedro"; studentNo="2021100234"; program="BS Information Technology / 4" }
    [ordered]@{ id="acc-staff"; username="Staff@mymail.mapua.edu.ph"; password="Staff1"; role="staff"; name="Staff Member"; studentNo=$null; program=$null }
    [ordered]@{ id="acc-admin"; username="11111"; password="x-admin"; role="admin"; name="System Administrator"; studentNo=$null; program=$null }
  )
}

function Get-SafeAccount {
  param($a)
  return [ordered]@{ id=$a.id; username=$a.username; role=$a.role; name=$a.name; studentNo=$a.studentNo; program=$a.program }
}

function Read-JsonBody {
  param($request)
  if ($request.HttpMethod -eq "GET" -or $request.HttpMethod -eq "OPTIONS") { return @{} }
  $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
  $raw = $reader.ReadToEnd()
  $reader.Close()
  if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
  return (ConvertTo-Hashtable ($raw | ConvertFrom-Json))
}

function Write-JsonResponse {
  param($response, [int]$status, $obj)
  $json = $obj | ConvertTo-Json -Depth 20
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $response.StatusCode = $status
  $response.ContentType = "application/json; charset=utf-8"
  $response.Headers.Add("Access-Control-Allow-Origin", "*")
  $response.Headers.Add("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
  $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
  $response.ContentLength64 = $bytes.Length
  $response.OutputStream.Write($bytes, 0, $bytes.Length)
  $response.OutputStream.Close()
}

Initialize-State

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "DocuRoute prototype backend listening on http://localhost:$Port/api"
Write-Host "Temporary database file: $DbPath"
Write-Host "Press Ctrl+C to stop."

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.AbsolutePath
    $method = $request.HttpMethod

    try {
      if ($method -eq "OPTIONS") {
        Write-JsonResponse $response 204 @{}
      }
      elseif ($path -eq "/api/health") {
        Write-JsonResponse $response 200 @{ ok = $true; time = (Get-Date).ToUniversalTime().ToString("o") }
      }
      elseif ($path -eq "/api/requests" -and $method -eq "GET") {
        Write-JsonResponse $response 200 @{ seq = $Script:State.seq; requests = $Script:State.requests }
      }
      elseif ($path -eq "/api/requests" -and $method -eq "POST") {
        $body = Read-JsonBody $request
        $type = [string]$body.type
        if (-not $ROUTES.ContainsKey($type)) {
          Write-JsonResponse $response 400 @{ error = "unknown document type: $type" }
        } else {
          $id = New-RequestId
          $req = [ordered]@{
            id = $id; type = $type; student = [string]$body.student; studentNo = [string]$body.studentNo
            program = [string]$body.program; nationality = "Filipino"; contactNo = [string]$body.contactNo
            fields = $body.fields; confidence = $null; route = @($ROUTES[$type]); hop = 0
            status = "submitted"; log = @()
          }
          Add-Log $req "Submitted by $($req.student) - document uploaded to DocuRoute."
          $Script:State.requests = @($req) + $Script:State.requests
          Save-State
          Write-JsonResponse $response 200 $req
        }
      }
      elseif ($path -match '^/api/requests/([^/]+)/classify$' -and $method -eq "POST") {
        $req = Find-Request $Matches[1]
        if (-not $req) { Write-JsonResponse $response 404 @{ error = "not found" } }
        else {
          $confidence = Get-Random -Minimum 55 -Maximum 100
          $req.status = "review"
          Add-Log $req "AI Processing Layer: image rectified, OCR extracted, layout-aware classification run."
          $req.confidence = $confidence
          if ($confidence -lt 70) {
            $req.status = "unverified"
            Add-Log $req "Confidence $confidence% is below the 70% threshold - flagged 'Unverified' and sent to the intake clerk queue."
          } else {
            $req.status = "routed"
            Add-Log $req "Confidence $confidence% - deterministic routing table assigned this to $($req.route[0]). QR sticker printed, digital twin archived."
          }
          Save-State
          Write-JsonResponse $response 200 $req
        }
      }
      elseif ($path -match '^/api/requests/([^/]+)/confirm$' -and $method -eq "POST") {
        $req = Find-Request $Matches[1]
        if (-not $req) { Write-JsonResponse $response 404 @{ error = "not found" } }
        else {
          $req.status = "routed"
          Add-Log $req "Intake clerk manually confirmed the document type - routed to $($req.route[0])."
          Save-State
          Write-JsonResponse $response 200 $req
        }
      }
      elseif ($path -match '^/api/requests/([^/]+)/advance$' -and $method -eq "POST") {
        $req = Find-Request $Matches[1]
        if (-not $req) { Write-JsonResponse $response 404 @{ error = "not found" } }
        else {
          if ($req.status -eq "routed") {
            $req.status = "progress"
            Add-Log $req "$($req.route[$req.hop]) marked the request In Progress."
          } else {
            if ($req.hop -lt ($req.route.Count - 1)) {
              Add-Log $req "$($req.route[$req.hop]) cleared the request - forwarded to $($req.route[$req.hop + 1])."
              $req.hop = $req.hop + 1
              $req.status = "routed"
            } else {
              $req.status = "completed"
              Add-Log $req "$($req.route[$req.hop]) gave final approval. Audit trail closed."
            }
          }
          Save-State
          Write-JsonResponse $response 200 $req
        }
      }
      elseif ($path -match '^/api/requests/([^/]+)/decline$' -and $method -eq "POST") {
        $req = Find-Request $Matches[1]
        if (-not $req) { Write-JsonResponse $response 404 @{ error = "not found" } }
        else {
          $body = Read-JsonBody $request
          $reason = [string]$body.reason
          if ([string]::IsNullOrWhiteSpace($reason)) { $reason = "No reason given." }
          $req.status = "declined"
          Add-Log $req "$($req.route[$req.hop]) declined the request - reason: '$reason'."
          Save-State
          Write-JsonResponse $response 200 $req
        }
      }
      elseif ($path -eq "/api/reset" -and $method -eq "POST") {
        Reset-Demo
        Save-State
        Write-JsonResponse $response 200 @{ seq = $Script:State.seq; requests = $Script:State.requests }
      }
      elseif ($path -eq "/api/login" -and $method -eq "POST") {
        $body = Read-JsonBody $request
        $acct = Find-AccountByUsername ([string]$body.username)
        if (-not $acct -or $acct.password -ne [string]$body.password) {
          Write-JsonResponse $response 401 @{ error = "Invalid username or password." }
        } else {
          Write-JsonResponse $response 200 (Get-SafeAccount $acct)
        }
      }
      elseif ($path -eq "/api/accounts" -and $method -eq "GET") {
        $safe = @($Script:State.accounts | ForEach-Object { Get-SafeAccount $_ })
        Write-JsonResponse $response 200 @{ accounts = $safe }
      }
      elseif ($path -eq "/api/accounts" -and $method -eq "POST") {
        $body = Read-JsonBody $request
        $username = [string]$body.username
        if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace([string]$body.password) -or [string]::IsNullOrWhiteSpace([string]$body.name)) {
          Write-JsonResponse $response 400 @{ error = "Username, password, and display name are required." }
        } elseif (Find-AccountByUsername $username) {
          Write-JsonResponse $response 400 @{ error = "That username is already in use." }
        } else {
          $acct = [ordered]@{
            id = New-AccountId; username = $username; password = [string]$body.password
            role = [string]$body.role; name = [string]$body.name
            studentNo = $body.studentNo; program = $body.program
          }
          $Script:State.accounts = @($Script:State.accounts) + $acct
          Save-State
          Write-JsonResponse $response 200 (Get-SafeAccount $acct)
        }
      }
      elseif ($path -match '^/api/accounts/([^/]+)$' -and $method -eq "PATCH") {
        $acct = Find-Account $Matches[1]
        if (-not $acct) {
          Write-JsonResponse $response 404 @{ error = "not found" }
        } else {
          $body = Read-JsonBody $request
          $newUsername = if ($body.username) { [string]$body.username } else { $null }
          $dupe = if ($newUsername -and $newUsername -ne $acct.username) { Find-AccountByUsername $newUsername } else { $null }
          if ($dupe -and $dupe.id -ne $acct.id) {
            Write-JsonResponse $response 400 @{ error = "That username is already in use." }
          } else {
            if ($newUsername) { $acct.username = $newUsername }
            if ($body.password) { $acct.password = [string]$body.password }
            if ($body.role) { $acct.role = [string]$body.role }
            if ($body.name) { $acct.name = [string]$body.name }
            Save-State
            Write-JsonResponse $response 200 (Get-SafeAccount $acct)
          }
        }
      }
      elseif ($path -match '^/api/accounts/([^/]+)$' -and $method -eq "DELETE") {
        $acct = Find-Account $Matches[1]
        if (-not $acct) {
          Write-JsonResponse $response 404 @{ error = "not found" }
        } else {
          $adminCount = @($Script:State.accounts | Where-Object { $_.role -eq "admin" }).Count
          if ($acct.role -eq "admin" -and $adminCount -le 1) {
            Write-JsonResponse $response 400 @{ error = "Cannot delete the last remaining admin account." }
          } else {
            $Script:State.accounts = @($Script:State.accounts | Where-Object { $_.id -ne $acct.id })
            Save-State
            Write-JsonResponse $response 200 @{ ok = $true }
          }
        }
      }
      else {
        Write-JsonResponse $response 404 @{ error = "not found" }
      }
      Write-Host "$method $path -> $($response.StatusCode)"
    }
    catch {
      Write-Host "ERROR handling $method $path : $($_.Exception.Message)"
      try { Write-JsonResponse $response 500 @{ error = $_.Exception.Message } } catch {}
    }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}
