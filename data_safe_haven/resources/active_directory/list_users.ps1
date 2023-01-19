param (
    [Parameter(Mandatory = $false, HelpMessage = "SRE name")]
    [string]$SREName = $null #this sets $SREName to an empty string, not to NULL
)

# Find SRE security group if an SRE name is specified
if (![string]::IsNullOrEmpty($SREName)) {
    $SREGroup = Get-ADGroup -Filter "Name -like '*SRE $SREName*'" | Where-Object { $_.DistinguishedName -like '*Data Safe Haven Security Groups*' } | Select-Object -First 1
}

# Return all matching users
$UserOuPath = (Get-ADObject -Filter * | Where-Object { $_.Name -eq "Data Safe Haven Research Users" }).DistinguishedName
foreach ($User in $(Get-ADUser -Filter * -SearchBase $UserOuPath -Properties TelephoneNumber,Mail,MemberOf)) {
    if ((![string]::IsNullOrEmpty($SREName)) -and -not ($User.MemberOf.Contains($SREGroup.DistinguishedName))) { continue }
    Write-Output "$($User.SamAccountName);$($User.GivenName);$($User.Surname);$($User.TelephoneNumber);$($User.Mail);$($User.UserPrincipalName)"
}
