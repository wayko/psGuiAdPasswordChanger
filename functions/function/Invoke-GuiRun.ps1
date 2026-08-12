<#
.SYNOPSIS
    Runs a What-if (simulate) or live password change from the GUI buttons, then
    writes the HTML + CSV reports.
#>
function Invoke-GuiRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [bool]$Live
    )

    $c = $script:App.Controls

    if (-not $script:App.Policy) {
        [System.Windows.MessageBox]::Show('Connect to AD first (Connect & Load AD).', 'Not connected',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $users = @(Get-SelectedUser)
    if ($users.Count -eq 0) {
        [System.Windows.MessageBox]::Show('No users selected.', 'Nothing to do',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }

    # Test mode always forces a simulation, even if the live button was pressed.
    $whatIf = $true
    if ($Live -and -not $c.ChkTestMode.IsChecked) { $whatIf = $false }
    if ($Live -and $c.ChkTestMode.IsChecked) {
        Write-AppLog 'Test mode is ON - live run downgraded to What-if.' 'WARN'
    }

    # Account options.
    $applyOpts = [bool]$c.ChkChangeOptions.IsChecked
    $opts = @{}
    if ($applyOpts) {
        if ($c.ChkPne.IsChecked -and $c.ChkMustChange.IsChecked) {
            [System.Windows.MessageBox]::Show(
                "'Password never expires' and 'Must change password at next logon' cannot both be enabled.",
                'Conflicting options', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        $opts.Enabled               = [bool]$c.ChkEnabled.IsChecked
        $opts.Unlock                = [bool]$c.ChkUnlock.IsChecked
        $opts.PasswordNeverExpires  = [bool]$c.ChkPne.IsChecked
        $opts.ChangePasswordAtLogon = [bool]$c.ChkMustChange.IsChecked
    }

    # Confirm a live run.
    if (-not $whatIf) {
        $answer = [System.Windows.MessageBox]::Show(
            ("You are about to CHANGE passwords for {0} user(s) in LIVE mode. Continue?" -f $users.Count),
            'Confirm live change', [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-AppLog 'Live run cancelled by user.' 'INFO'
            return
        }
    }

    $generator = Get-GuiGeneratorSetting

    # If a password was typed in the box, it must satisfy the domain policy.
    if ($generator.FixedPassword) {
        $chk = Test-PasswordCompliance -Password $generator.FixedPassword -Policy $script:App.Policy
        if (-not $chk.Ok) {
            [System.Windows.MessageBox]::Show(
                ("The password you entered does not meet the domain policy:`n - {0}" -f ($chk.Reasons -join "`n - ")),
                'Password not allowed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            Write-AppLog 'Manual password rejected - does not meet the domain policy.' 'WARN'
            return
        }
    }

    try {
        $c.BtnWhatIf.IsEnabled = $false; $c.BtnLive.IsEnabled = $false
        $results = Invoke-PasswordRun -Users $users -Policy $script:App.Policy -WhatIf $whatIf `
                    -Generator $generator -ApplyAccountOptions $applyOpts -AccountOptions $opts

        $report = Save-Report -Results $results -WhatIf $whatIf -Combined ([bool]$script:App.Config.Report.CombinedReportByDefault)
        Write-AppLog ("DONE. Reports in: {0}" -f $report.Folder) 'INFO'
    }
    catch {
        Write-AppLog ("Run error: {0}" -f $_.Exception.Message) 'ERROR'
    }
    finally {
        $c.BtnWhatIf.IsEnabled = $true; $c.BtnLive.IsEnabled = $true
    }
}
