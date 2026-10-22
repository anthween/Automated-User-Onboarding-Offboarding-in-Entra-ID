# C:\IAMLab\Provision-Users.ps1
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

 
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All"

$csvPath = ".\new_hires.csv"
if (-not (Test-Path $csvPath)) {
    Write-Error "CSV file not found at $csvPath!"
    exit
}

$newHires = Import-Csv -Path $csvPath

 
$tenantDomain = (Get-MgOrganization).VerifiedDomains | Where-Object { $_.IsDefault } | Select-Object -ExpandProperty Name
Write-Host "Connected to domain: $tenantDomain`n" -ForegroundColor Green


foreach ($user in $newHires) {
    # Generate UPN (e.g. alex.mercer@domain.onmicrosoft.com)
    $upn = "$($user.FirstName.ToLower()).$($user.LastName.ToLower())@$tenantDomain"
    
    # Config temp credential rules
    $passwordProfile = @{
        Password = "Password12345!"
        ForceChangePasswordNextSignIn = $true
    }

    Write-Host "Creating account for: $upn ..." -ForegroundColor Cyan

    # Parametr hashtabel
    $userParams = @{
        DisplayName       = $user.DisplayName
        GivenName         = $user.FirstName
        SurName           = $user.LastName
        JobTitle          = $user.JobTitle
        Department        = $user.Department
        UserPrincipalName = $upn
        MailNickname      = "$($user.FirstName.ToLower())$($user.LastName.ToLower())"
        AccountEnabled    = $true
        PasswordProfile   = $passwordProfile
    }

    $newUser = New-MgUser @userParams

    if ($user.GroupTarget) {
        $group = Get-MgGroup -Filter "displayName eq '$($user.GroupTarget)'"
        if ($group) {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
            Write-Host "  [+] Added $($user.DisplayName) to group: $($user.GroupTarget)" -ForegroundColor Green
        } else {
            Write-Host "  [-] Group '$($user.GroupTarget)' not found in tenant!" -ForegroundColor Red
        }
    }
}

Write-Host "`n[SUCCESS] Automated User Provisioning Done ^^!" -ForegroundColor Yellow