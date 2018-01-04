function CheckNewUsersAndGroups () {
<#
	.SYNOPSIS
		Check for new users and groups based on creation date
	.DESCRIPTION
		Check for new users and groups based on creation date. This list is then exported and e-mailed to MIM admins to allow them to start new migration jobs.
	.NOTES
	.LINK
	.EXAMPLE
		TBD
	.PARAMETER length
		TBD
#>

	[CmdletBinding()]
	param (
		[parameter(Mandatory=$true)]
		[string]$time,
		[parameter(Mandatory=$false)]
		[string]$Hours=4,
		[parameter(Mandatory=$false)]
		[string[]]$Sites=("FR-SMC","IT-CRE","BE-AC")
	)

    #Importing modules
    if(!(Get-Module ActiveDirectory -All)) {
	   	Import-Module ActiveDirectory
       }
	if(!(Get-Module Logging -All)) {
		Import-Module ([string]::join("",((split-path $PSScriptRoot -parent).ToString(),"\lib\powershell\Logging"))) -Force
	}

	$limit = (Get-Date).AddHours(-$hours)
	$newlycreatedusers = Get-ADUser -server ktn.group -Filter * -Properties Created
	$newlycreatedgroups = Get-ADGroup -server ktn.group -filter * -properties Created 
	
	foreach ($item in $sites) {
		$effectiveusers = $newlycreatedusers |? {$_.Distinguishedname -like "*$item*" -and $_.Created -ge $limit}
		if ($effectiveusers) {
			$newsessionusersfilename = $time + "_GeneratedListNewUsersSince_" + (Get-Date($limit) -Format "yyyyMMdd-HHmmss")
			$newsessionusersfilenamepath = ("\\s-be-ki-qadc\MigrationSessions\ToBeValidated\" + $newsessionusersfilename + ".txt")
			if (!(Test-Path $newsessionusersfilenamepath)) {
				Write-XXLog ((Get-Date -Format G) + ": Creating new file: " + $newsessionusersfilename + ".txt")
				"Distinguishedname" | Out-File $newsessionusersfilenamepath
			}
			$attach = Get-Item $logfile	
			$attach2 = get-item $newsessionusersfilenamepath
			$effectiveusers |% {$_.Distinguishedname | Out-File $newsessionusersfilenamepath -Append}
		}
	}

	foreach ($item in $sites) {
		$effectivegroups = $newlycreatedgroups |? {$_.Distinguishedname -like "*$item*" -and $_.Created -ge $limit}
		if ($effectivegroups) {
			$newsessiongroupsfilename = $time + "_GeneratedListNewGroupsSince_" + (Get-Date($limit) -Format "yyyyMMdd-HHmmss")
			$newsessiongroupsfilenamepath = ("\\s-be-ki-qadc\MigrationSessions\ToBeValidated\" + $newsessiongroupsfilename + ".txt")
			if (!(Test-Path $newsessiongroupsfilenamepath)) {
				Write-XXLog ((Get-Date -Format G) + ": Creating new file: " + $newsessiongroupsfilename + ".txt")
				"Distinguishedname" | Out-File $newsessiongroupsfilenamepath
			}
			$attach = Get-Item $logfile	
			$attach3 = get-item $newsessiongroupsfilenamepath
			$effectivegroups |% {$_.Distinguishedname | Out-File $newsessiongroupsfilenamepath -Append}
		}		
	}
	
	if ($attach) {
		Write-XXLog ((Get-Date -Format G) + ": Sending e-mail confirmation with attached logfile")
		$from = "MIM_Drone@katoennatie.com"
		$to = "dennis.dehouwer@katoennatie.com","koen.arys@katoennatie.com","tijs.vandenBroeck@katoennatie.com"
		$subject = "[MIM] Check New Non-Synced Users And Groups"
		$smtp = "s-be-ki-smtp.ktn.group"
		if ($attach2 -ne $null -and $attach3 -ne $null) {
			Send-MailMessage -From $from -To $to -Subject $subject -Attachments $attach, $attach2, $attach3 -SmtpServer $smtp
		}
		if ($attach2 -ne $null -and $attach3 -eq $null) {
			Send-MailMessage -From $from -To $to -Subject $subject -Attachments $attach, $attach2 -SmtpServer $smtp
		}
		if ($attach2 -eq $null -and $attach3 -ne $null) {
			Send-MailMessage -From $from -To $to -Subject $subject -Attachments $attach, $attach3 -SmtpServer $smtp
		}
	}
}

$currenttime = (get-date -format yyyyMMdd-HHmmss)
$global:_logfile = "c:\logs\MIM\CheckNewUsersAndGroups_" + $currenttime + ".log"
$logfile = $global:_logfile
CheckNewUsersAndGroups ($currenttime)