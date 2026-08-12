<#
.SYNOPSIS
    Lazy-load: returns the normalized user objects directly in an OU.
#>
function Get-AdOuUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$OuDN,
        [ValidateSet('OneLevel', 'Subtree')] [string]$Scope = 'OneLevel',
        [object]$Config = $script:App.Config
    )

    if ($script:App.DemoMode) {
        return Get-DemoData -Level 'Users' -Parent $OuDN
    }

    $server = $Config.Domain.Server
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }

    $props = @('DisplayName', 'Enabled', 'LockedOut', 'PasswordNeverExpires', 'UserPrincipalName',
               'PasswordExpired', 'msDS-UserPasswordExpiryTimeComputed', 'AccountExpirationDate')
    foreach ($a in @($Config.Attributes.PersonalIdAttribute, $Config.Attributes.DisplayNameAttribute)) {
        if ($a -and $props -notcontains $a) { $props += $a }
    }

    $users = Get-ADUser -SearchBase $OuDN -SearchScope $Scope -Filter * -Properties $props @common |
             Sort-Object Name

    return @($users | ConvertTo-UserObject -Config $Config)
}
