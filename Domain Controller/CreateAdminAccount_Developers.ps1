function _generatePasswrd () {
<#
    .SYNOPSIS
        Create a random generated password

    .DESCRIPTION
        Create a random generated password

    .EXAMPLE
        _generatePasswrd -length 12

    .NOTES
    None

    .PARAMETER length
        The specified length of the password (default = 9)
#>

    [CmdletBinding()]
    param ( 
        [int]$Length = 12, 
        [int]$NonAlphanumericChar = 1 
    )

    $Assembly = Add-Type -AssemblyName System.Web
    $RandomComplexPassword = [System.Web.Security.Membership]::GeneratePassword($Length,$NonAlphanumericChar)
    return $RandomComplexPassword
}

function New-XXAdminUser {
<#
    .SYNOPSIS
        Generates suitable user names based on input and verifies against existence

    .DESCRIPTION
        Generates suitable user names based on input and verifies against existence

    .EXAMPLE
        New-XXAdminUser --Surname Dehouwer -GivenName Dennis

    .NOTES
        None
#>
    
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
	    [String[]]$Surname,
	    [parameter(Mandatory=$true)]
	    [String[]]$GivenName
    )

    $unique = $false
    $uniqueindex = 0

    do {
        $surname = $surname -replace(" ","")
        if ($($surname).Length -lt 7) {
	    $result = $surname.ToLower() 
        }   
        else {
            $result = ($surname.Substring(0,7)).ToLower()
        }
        if ($uniqueindex -eq 0) {
	        $result += ($GivenName.Substring(0,1)).ToLower()
        }
        else {
   	        $result += ($GivenName.Substring(0,1)).ToLower()
            $result += $uniqueindex
        }
        $result += "_admin"
    
        if (!(Get-ADUser -filter {SAMAccountName -eq $result})) {
  	        $unique = $true
        }
        else {
  	        $uniqueindex++
        }
    }
    until ($unique -eq $true)

    return $result
}

function Set-XXAdminUser {
<#
    .SYNOPSIS
        Enables an admin user based on a regular user account

    .DESCRIPTION
        Enables an admin user based on a regular user account and populates the most popular fields. No parameter input is required, this is obtained through user input at script execution. `

    .EXAMPLE
        Set-XXAdminUser

    .NOTES
        The user input support an array of values.
#>
	
    [CmdletBinding()]
    param (
    	[parameter(Mandatory=$true)]
	    [String[]]$User
    )

    #Importing modules
    if(!(Get-Module ActiveDirectory -All)) {
        Import-Module ActiveDirectory
    }
    if(!(Get-Module Logging -All)) {
        Import-Module ([string]::join("",((split-path $PSScriptRoot -parent).ToString(),"\lib\powershell\Logging"))) -Force
    }
        
    foreach ($usr in $user) {
        try {
            $useraccount = Get-ADUser $usr -Properties EmailAddress, MemberOf
            $displayname = ($useraccount.Surname + ", " + $useraccount.GivenName + " Admin")
      	    $newsam = New-XXAdminUser -Surname $useraccount.Surname -GivenName $useraccount.GivenName             
            $password = _generatePasswrd
          
            New-ADUser -Server itglo.net -Name $displayname -SamAccountName ($newsam) -Path "OU=Admin Accounts,OU=Users,OU=Base,DC=itglo,DC=net" -GivenName ($useraccount.GivenName) -Surname ($useraccount.Surname + " Admin") -DisplayName ($displayname) -Description ("KTNBEL\" + $useraccount.SAMAccountName) -AccountPassword ($password | ConvertTo-SecureString -AsPlainText -Force) -UserPrincipalName ($newsam + "@katoennatie.com") -ChangePasswordAtLogon $true -enabled $true
            Start-Sleep -Seconds 5
            Add-ADGroupMember -Identity "Developer Administrators" -Members $newsam
               
            Send-MailMessage -from "admincreation@katoennatie.com" -to $useraccount.EmailAddress -subject ("Admin account created for " + $displayname) -Body ("Useraccount: ITGLO\" + $newsam + "`nPassword: " + $password) -SmtpServer "s-be-ki-smtp.ktn.group"
            Write-XXLog ((Get-Date -Format G) + ": Useraccount created: " + $newsam)
            Write-XXLog ((Get-Date -Format G) + ": Added user to group: Developer Administrators")
            Write-XXLog ((Get-Date -Format G) + ": Details have been e-mailed to " + $useraccount.EmailAddress)

        }
        catch {
            Write-XXLog ((Get-Date -Format G) + ": An error occurred, please investigate...") -color Red
            Write-XXLog ((Get-Date -Format G) + ": " + $_) -color Red
        }
    }
}

$currenttime = (get-date -format MMddyyyy-HHmmss)
$global:_logfile = "c:\logs\CreateAdminAccount_" + $currenttime + ".log"
$logfile = $global:_logfile
[String[]]$usertocreate = (Read-Host -Prompt "Enter user for which to create an admin account (multiple entries possible, use typed csv)").split(",") |% {$_.trim()}
Set-XXAdminUser -User $usertocreate