<#
.SYNOPSIS
    Applies the Show (active/disabled) dropdown to the visibility of loaded
    user nodes in the OU tree.
#>
function Update-UserFilter {
    [CmdletBinding()] param()

    $c = $script:App.Controls

    $showIdx = $c.CmbShow.SelectedIndex   # 0 all, 1 active, 2 disabled

    foreach ($item in (Get-TreeItem -Parent $c.TreeAd -OnlyLoaded)) {
        $meta = $item.Tag
        if ($meta.Type -ne 'User') { continue }
        $stu = $meta.User
        $visible = $true

        # Status
        if ($showIdx -eq 1 -and -not $stu.Enabled) { $visible = $false }
        if ($showIdx -eq 2 -and $stu.Enabled)      { $visible = $false }

        $item.Visibility = if ($visible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    Update-SelectedCount
}
