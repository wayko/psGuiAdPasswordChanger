<#
.SYNOPSIS
    Applies the account option changes to a single user (enable/disable, unlock,
    password-never-expires, must-change-at-next-logon).
.NOTES
    "Password never expires" and "must change at next logon" are mutually exclusive
    in Active Directory. The caller (GUI) blocks selecting both, and this function
    enforces it defensively as well.
#>
function Set-AdAccountOption {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [object]$User,
        [Nullable[bool]]$Enabled,
        [switch]$Unlock,
        [Nullable[bool]]$PasswordNeverExpires,
        [Nullable[bool]]$ChangePasswordAtLogon,
        [object]$Config = $script:App.Config
    )

    # Defensive mutual-exclusion guard.
    if ($PasswordNeverExpires -eq $true -and $ChangePasswordAtLogon -eq $true) {
        throw "'Password never expires' and 'Must change password at next logon' cannot both be enabled."
    }

    $applied = New-Object System.Collections.Generic.List[string]

    if ($script:App.DemoMode) {
        if ($Enabled -ne $null)              { $applied.Add($(if($Enabled){'enabled'}else{'disabled'})) }
        if ($Unlock)                         { $applied.Add('unlocked') }
        if ($PasswordNeverExpires -ne $null) { $applied.Add("PNE=$PasswordNeverExpires") }
        if ($ChangePasswordAtLogon -ne $null){ $applied.Add("MustChange=$ChangePasswordAtLogon") }
        return ,$applied.ToArray()
    }

    $server = $Config.Domain.Server
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }
    $id = $User.DistinguishedName

    if ($Enabled -ne $null) {
        if ($Enabled) {
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Enable-ADAccount')) {
                Enable-ADAccount -Identity $id @common; $applied.Add('enabled')
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Disable-ADAccount')) {
                Disable-ADAccount -Identity $id @common; $applied.Add('disabled')
            }
        }
    }

    if ($Unlock) {
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Unlock-ADAccount')) {
            Unlock-ADAccount -Identity $id @common; $applied.Add('unlocked')
        }
    }

    $setParams = @{}
    if ($PasswordNeverExpires -ne $null)  { $setParams.PasswordNeverExpires  = [bool]$PasswordNeverExpires }
    if ($ChangePasswordAtLogon -ne $null) { $setParams.ChangePasswordAtLogon = [bool]$ChangePasswordAtLogon }
    if ($setParams.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Set-ADUser $($setParams.Keys -join ',')")) {
            Set-ADUser -Identity $id @setParams @common
            foreach ($k in $setParams.Keys) { $applied.Add("$k=$($setParams[$k])") }
        }
    }

    return ,$applied.ToArray()
}
