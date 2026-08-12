<#
.SYNOPSIS
    Orchestrates a password run over the selected users (Test/What-if or live).
.OUTPUTS
    Array of result rows (one per user) for the reports.
#>
function Invoke-PasswordRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Users,
        [Parameter(Mandatory)] [object]$Policy,
        [bool]$WhatIf = $true,
        [hashtable]$Generator = @{},
        [bool]$ApplyAccountOptions = $false,
        [hashtable]$AccountOptions = @{}
    )

    $cfg = $script:App.Config
    $g   = $cfg.Generator

    # Merge generator settings (GUI overrides win, else config defaults).
    $len     = if ($Generator.ContainsKey('Length'))     { [int]$Generator.Length }     else { [int]$g.DefaultLength }
    $useU    = if ($Generator.ContainsKey('UseUpper'))   { [bool]$Generator.UseUpper }  else { [bool]$g.UseUpper }
    $useL    = if ($Generator.ContainsKey('UseLower'))   { [bool]$Generator.UseLower }  else { [bool]$g.UseLower }
    $useD    = if ($Generator.ContainsKey('UseDigit'))   { [bool]$Generator.UseDigit }  else { [bool]$g.UseDigit }
    $useS    = if ($Generator.ContainsKey('UseSpecial')) { [bool]$Generator.UseSpecial }else { [bool]$g.UseSpecial }
    $special = if ($Generator.ContainsKey('SpecialChars')){ [string]$Generator.SpecialChars } else { [string]$g.SpecialChars }
    $sameAll = if ($Generator.ContainsKey('SamePasswordForAll')) { [bool]$Generator.SamePasswordForAll } else { [bool]$g.SamePasswordForAll }
    $avoid   = [bool]$g.AvoidAmbiguous

    $fixed = if ($Generator.ContainsKey('FixedPassword') -and $Generator.FixedPassword) { [string]$Generator.FixedPassword } else { $null }

    $sharedPassword = $null
    if ($fixed) {
        # A password typed in the box is used verbatim for every selected user.
        $sharedPassword = $fixed
        Write-AppLog 'Using the manually entered password for all selected users.' 'INFO'
    }
    elseif ($sameAll) {
        $sharedPassword = New-CompliantPassword -Policy $Policy -Length $len -UseUpper $useU -UseLower $useL -UseDigit $useD -UseSpecial $useS -SpecialChars $special -AvoidAmbiguous $avoid
    }

    $mode = if ($WhatIf) { 'TEST MODE (What-if) - nothing will be changed' } else { 'LIVE MODE - passwords WILL be changed' }
    Write-AppLog ("Starting {0} user(s). Mode: {1}. Generator via GPO policy (min {2} chars, complexity {3})." -f `
        $Users.Count, $mode, $Policy.MinPasswordLength, $(if($Policy.ComplexityEnabled){'ON'}else{'OFF'})) 'INFO'

    $results = New-Object System.Collections.Generic.List[object]
    $errors  = 0

    foreach ($user in $Users) {
        # Account options first (so an account can be enabled before/independently of the reset).
        if ($ApplyAccountOptions) {
            try {
                $optParams = @{ User = $user }
                if ($AccountOptions.ContainsKey('Enabled'))               { $optParams.Enabled = [bool]$AccountOptions.Enabled }
                if ($AccountOptions['Unlock'])                            { $optParams.Unlock  = $true }
                if ($AccountOptions.ContainsKey('PasswordNeverExpires'))  { $optParams.PasswordNeverExpires  = [bool]$AccountOptions.PasswordNeverExpires }
                if ($AccountOptions.ContainsKey('ChangePasswordAtLogon')) { $optParams.ChangePasswordAtLogon = [bool]$AccountOptions.ChangePasswordAtLogon }
                if ($WhatIf) { $optParams.WhatIf = $true }
                $applied = Set-AdAccountOption @optParams
                if ($applied) { Write-AppLog ("{0}: options {1}" -f $user.SamAccountName, ($applied -join ', ')) 'DEBUG' }
            }
            catch {
                Write-AppLog ("{0}: account option error - {1}" -f $user.SamAccountName, $_.Exception.Message) 'ERROR'
            }
        }

        # Password (always via generator - no hard-coded pattern).
        $pw = if ($sharedPassword) { $sharedPassword } else {
            New-CompliantPassword -Policy $Policy -Length $len -UseUpper $useU -UseLower $useL -UseDigit $useD -UseSpecial $useS -SpecialChars $special -AvoidAmbiguous $avoid
        }

        $row = if ($WhatIf) {
            Set-AdUserPassword -User $user -Password $pw -WhatIf
        } else {
            Set-AdUserPassword -User $user -Password $pw
        }

        if ($row.State -eq 'FAILED') {
            $errors++
            Write-AppLog ("{0}: FAILED - {1}" -f $user.SamAccountName, $row.Message) 'ERROR'
        }
        $results.Add($row)
    }

    $changed = ($results | Where-Object { $_.State -in @('OK', 'WHATIF') }).Count
    Write-AppLog ("Run complete. {0} processed, {1} error(s)." -f $changed, $errors) $(if($errors){'WARN'}else{'INFO'})

    return $results.ToArray()
}
