<#
.SYNOPSIS
    Reads the effective GPO password policy from the domain (default domain policy).
.DESCRIPTION
    Returns a normalized object describing minimum length, complexity, history, etc.
    Falls back to a sane demo policy when AD is not available.
#>
function Get-AdPasswordPolicy {
    [CmdletBinding()]
    param(
        [string]$Server = $script:App.Config.Domain.Server
    )

    if (-not $script:App.AdAvailable) {
        Write-AppLog 'ActiveDirectory not available - using demo password policy.' 'WARN'
        return [pscustomobject]@{
            Source            = 'Demo'
            MinPasswordLength = 8
            ComplexityEnabled = $true
            PasswordHistory   = 24
            MinPasswordAgeDays= 1
            MaxPasswordAgeDays= 42
            LockoutThreshold  = 5
            RequiredCategories= 3
        }
    }

    try {
        $params = @{ ErrorAction = 'Stop' }
        if ($Server) { $params.Server = $Server }
        $p = Get-ADDefaultDomainPasswordPolicy @params

        return [pscustomobject]@{
            Source            = 'Default Domain Policy'
            MinPasswordLength = [int]$p.MinPasswordLength
            ComplexityEnabled = [bool]$p.ComplexityEnabled
            PasswordHistory   = [int]$p.PasswordHistoryCount
            MinPasswordAgeDays= [int]$p.MinPasswordAge.TotalDays
            MaxPasswordAgeDays= [int]$p.MaxPasswordAge.TotalDays
            LockoutThreshold  = [int]$p.LockoutThreshold
            RequiredCategories= $(if ($p.ComplexityEnabled) { 3 } else { 0 })
        }
    }
    catch {
        Write-AppLog "Could not read domain password policy: $($_.Exception.Message)" 'ERROR'
        throw
    }
}
