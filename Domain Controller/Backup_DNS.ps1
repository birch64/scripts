<# 
   Description: Backup script to back-up the DHCP configuration

   Author: Dennis Dehouwer
   Date: 3/1/2018
   Version: 1.0
#>

#Importing modules
if(!(Get-Module Logging -All)) {
	Import-Module ([string]::join("",((split-path $PSScriptRoot -parent).ToString(),"\lib\powershell\Logging"))) -Force
}
if(!(Get-Module DnsShell -All)) {
	Import-Module ([string]::join("",((split-path $PSScriptRoot -parent).ToString(),"\lib\powershell\DnsShell"))) -Force
} 

#Init
$computername = $env:computername
$systemdir = $env:windir + "\System32"
$backuptime = (get-date -format MMddyyyy-HHmmss)
$global:_logfile = "c:\logs\Backup_DNS_" + $computername + "_" + $backuptime + ".log"
$logfile = $global:_logfile

function Backup_DNS {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$true)]
		[string]$BackupTarget
	)
	
	Write-XXLog ((Get-Date -Format G) + "   Backup starting, please wait...")
	Write-XXLog ("")
	
	
	
	$zones = Get-Dnszone -Zonetype primary -server $computername
	$NewPath = New-Item -ItemType Directory -Path ($BackupTarget + "\" + $computername + "_" + $backuptime)
	$litnewpath = [string]$NewPath
	$err = $false
	$process =  New-Object System.Diagnostics.ProcessStartInfo
	$process.FileName = "dnscmd.exe"
	$process.RedirectStandardOutput = $true
	$process.UseShellExecute = $false
	$p = New-Object System.Diagnostics.Process
	foreach ($zone in $zones) {
        $zonename = $zone.zonename
		$process.Arguments = "/zoneexport $zonename $zonename.bak"	
		$p.Startinfo = $process
		$p.Start() | Out-Null
		while (!$p.HasExited){
			if($p.StandardOutput){
				Write-XXLog ($p.StandardOutput.ReadLine())
			 }
		}
		$output = $p.StandardOutput.ReadToEnd()
		Write-XXLog ($output)
		$p.WaitForExit()

        if ($p.ExitCode -ne 0) {
            $err = $true
            $errcode = $p.ExitCode
        }
        Move-Item -path ($systemdir + "\dns\$zonename.bak") -Destination ($litnewpath + "\" + "$zonename.bak")
    }
	
	if ($err -eq $false) {
        Write-XXLog ((Get-Date -Format G) + "   The DNS backup of " + $computername + " has completed successfully")
        }
    else {
        Write-XXLog ((Get-Date -Format G) + "   The DNS backup of " + $computername + " has encountered error " + $errcode + ", please investigate...")
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
		
	$limit = (Get-Date).AddDays(-$Days)
	Write-XXLog ((Get-Date -Format G) + "   Removing back-up files older than " + $days + " days on " + $path + "...")
	gci -Path $path -Recurse -Force |? {!$_.PSIsContainer -and $_.CreationTime -lt $limit} | Remove-Item -Force
	gci -Path $path -Recurse -Force |? {$_.PSIsContainer -and (gci -Path $_.FullName -Recurse -Force |? {!$_.PSIsContainer}) -eq $null } | Remove-Item -Force -Recurse
}

function Copy-NewBackup {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$false)]
		[string]$Source="Z:\Backup_DNS",
		[parameter(Mandatory=$false)]
		[string]$Destination="\\s-be-ki-d2d.ktn.group\Backup_DNS"
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
	$from = $computername + "_Backup_DNS@katoennatie.com"
	$to = "dennis.dehouwer@katoennatie.com","it_notification@katoennatie.com"
	$subject = "[Info] Backup DNS " + $computername + " Result"
	$smtp = "s-be-ki-smtp.ktn.group"
	
	Send-MailMessage -From $from -To $to -Subject $subject -Attachments $attach -SmtpServer $smtp
}

#Main
Backup_DNS -BackupTarget "Z:\Backup_DNS"
Remove-Backup -Path "\\s-be-ki-d2d.ktn.group\Backup_DNS" -Days 180
Copy-NewBackup
Remove-Backup -Path "Z:\Backup_DNS"
Send-MailOutput