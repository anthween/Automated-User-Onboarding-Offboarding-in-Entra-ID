# C:\IAMLab\Deprovision-Users.ps1
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement


Write-Host "Connecting to Microsoft Graph for Deprovisioning..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All"

$csvPath = ".\new_hires.csv"
if (-not (Test-Path $csvPath)) {
    Write-Error "CSV file not found at $csvPath!"
    exit
}

$offboardingUsers = Import-Csv -Path $csvPath
$tenantDomain = (Get-MgOrganization).VerifiedDomains | Where-Object { $_.IsDefault } | Select-Object -ExpandProperty Name


foreach ($user in $offboardingUsers) {
    $upn = "$($user.FirstName.ToLower()).$($user.LastName.ToLower())@$tenantDomain"
    
    # Check if user exists in directory
    $existingUser = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    
    if ($existingUser) {
        Write-Host "`n[Offboarding] Processing: $upn" -ForegroundColor Cyan
        
        $userGroups = Get-MgUserMemberOf -UserId $existingUser.Id
        foreach ($group in $userGroups) {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $existingUser.Id -ErrorAction SilentlyContinue
            Write-Host "  [-] Removed from Group ID: $($group.Id)" -ForegroundColor Yellow
        }

        Update-MgUser -UserId $existingUser.Id -AccountEnabled:$false
        Write-Host "  [!] Account status set to DISABLED." -ForegroundColor Red

        Revoke-MgUserSignInSession -UserId $existingUser.Id | Out-Null
        Write-Host "  [!] Revoked all active sign-in sessions." -ForegroundColor Red
        
    } else {
        Write-Host "User $upn not found in directory." -ForegroundColor Gray
    }
}

Write-Host "`n[SUCCESS] Offboarding & Access Revocation Process Done ^^!" -ForegroundColor Green