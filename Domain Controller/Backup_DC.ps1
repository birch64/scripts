<# 
   Description: Backup script to backup systemstate of DC's with additional logging

   Author: Dennis Dehouwer
   Date: 15/09/2015
   Version: 1.0
   
   CHANGES
   4/1/2018 (1.3):
    * Added github repository, for all future changes please check: https://github.com/birch64/scripts.git
   
	31/10/2016 (1.2 - Dennis Dehouwer)
    * Updated for new forest ITGLO.net
   
   20/10/2015 (1.1 - Bart Debo)
    * Fix local 5 day rotation by adding timestamp to backup folder.
    * Fix log file when process hangs.
#>

#Importing modules
if(!(Get-Module Logging -All)) {
	Import-Module ([string]::join("",((split-path $PSScriptRoot -parent).ToString(),"\lib\powershell\Logging"))) -Force
}

#Init
$computername = $env:computername
$systemdir = $env:windir + "\System32"
$backuptime = (get-date -format MMddyyyy-HHmmss)
$global:_logfile = "c:\logs\Backup_DC_" + $backuptime + ".log"
$logfile = $global:_logfile

function Backup_DC {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$true)]
		[string]$BackupTarget
	)
	
	Write-XXLog ((Get-Date -Format G) + "   Backup starting, this may take a while...")
	Write-XXLog ("")
	
	$process =  New-Object System.Diagnostics.ProcessStartInfo
	$process.FileName = "wbadmin.exe"
	$process.Arguments = "start systemstatebackup -backuptarget:" + $backuptarget + " -quiet"
	$process.RedirectStandardOutput = $true
	$process.UseShellExecute = $false
	
	$p = New-Object System.Diagnostics.Process
	$p.Startinfo = $process
	$p.Start() | Out-Null
    while (!$p.HasExited){
        if($p.StandardOutput){
            Write-XXLog ($p.StandardOutput.ReadLine())
         }
    }
    $output = $p.StandardOutput.ReadToEnd()
	$p.WaitForExit()
	
	Write-XXLog ($output)
	Write-XXLog ("")
	if ($p.ExitCode -eq 0) {
		Write-XXLog ((Get-Date -Format G) + "   The systemstate backup of " + $computername + " has completed successfully")
	}
	else {
		Write-XXLog ((Get-Date -Format G) + "   The systemstate backup of " + $computername + " has encountered error " + $output.exitcode)
	}
}

function Remove-Backup {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$true)]
		[string]$Path,
		[parameter(Mandatory=$false)]
		[string]$Days=5
	)
		
	$limit = (Get-Date).AddDays(-$days)
	Write-XXLog ((Get-Date -Format G) + "   Removing back-up files older than " + $days + " days on " + $path + "...")
	gci -Path $path -Recurse -Force |? {!$_.PSIsContainer -and $_.CreationTime -lt $limit} | Remove-Item -Force
	gci -Path $path -Recurse -Force |? {$_.PSIsContainer -and (gci -Path $_.FullName -Recurse -Force |? {!$_.PSIsContainer}) -eq $null } | Remove-Item -Force -Recurse
}

function Copy-NewBackup {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$false)]
		[string]$Source="Z:\WindowsImageBackup",
		[parameter(Mandatory=$false)]
		[string]$Destination="\\s-be-ki-d2d.ktn.group\Backup_AD"
	)
	
	Write-XXLog ((Get-Date -Format G) + "   Copying the new back-up to the archive location...")

	$ec = Start-Process -FilePath ($systemdir + "\robocopy.exe") -ArgumentList ("/e /r:10 /w:5 " + $source + " " + "`"" + $destination + "`"") -PassThru -Wait
	
	if ($ec.ExitCode -eq 0 -or $ec.ExitCode -eq 1 -or $ec.ExitCode -eq 2 -or $ec.ExitCode -eq 3) {
		Write-XXLog ((Get-Date -Format G) + "   The new back-up copy from " + $source + " to " + $destination + " has completed successfully")
		}
	else {
		Write-XXLog ((Get-Date -Format G) + "   The new back-up copy from " + $source + " to " + $destination + " has encountered error " + $ec.exitcode)
	}
}

function Send-MailOutput {
	Write-XXLog ((Get-Date -Format G) + "   Sending e-mail confirmation with attached logfile")
	Write-XXLog ((Get-Date -Format G) + "   Back-up finished!")
	
	$attach = Get-Item $logfile
	$from = $computername + "_Backup_AD@katoennatie.com"
	$to = "dennis.dehouwer@katoennatie.com","it_notification@katoennatie.com"
	$subject = "[Info] Backup AD " + $computername + " Result"
	$smtp = "s-be-ki-smtp.ktn.group"
	
	Send-MailMessage -From $from -To $to -Subject $subject -Attachments $attach -SmtpServer $smtp
}

#Main
Backup_DC -BackupTarget "Z:"
$rename = $computername + "_" + $backuptime
Rename-Item -path ("Z:\WindowsImageBackup\" + $computername) -newName $rename
Remove-Backup -Path "\\s-be-ki-d2d.ktn.group\Backup_AD"
Copy-NewBackup
Remove-Backup -Path "Z:\WindowsImageBackup"
Send-MailOutput