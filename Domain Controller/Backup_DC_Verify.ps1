<# DESCRIPTION: Backup DC Verify script
   AUTHOR: Dennis Dehouwer
   DATE: 22/09/2015
   Version: 1.1

   CHANGES
   4/1/2018:
    * Added github repository, for all future changes please check: https://github.com/birch64/scripts.git
#>

$computername = $env:computername
$from = $computername + "_Backup_AD@katoennatie.com"
$to = "dennis.dehouwer@katoennatie.com","it_notification@katoennatie.com"
$cc = "dirk.schippers@katoennatie.com","steve.belis@katoennatie.com"
$smtp = "s-be-ki-smtp.ktn.group"
$computername = $env:computername

$sched = New-Object -Com "Schedule.Service"
$sched.Connect()
$out = @()
$sched.GetFolder("\Backup").GetTasks(0) | where {$_.Name -eq "Backup DC"} | % {
    $xml = [xml]$_.xml
    $out += New-Object psobject -Property @{
        "Name" = $_.Name
        "Status" = switch($_.State) {0 {"Unknown"} 1 {"Disabled"} 2 {"Queued"} 3 {"Ready"} 4 {"Running"}}
        "LastRunTime" = $_.LastRunTime
        "LastRunResult" = $_.LastTaskResult
    }
}

$outmsg = "Name: " + $out.Name + "`r`n"
$outmsg += "Status: " + $out.Status + "`r`n"
$outmsg += "Last run time: " + $out.LastRunTime + "`r`n"
$outmsg += "Last run result: " + $out.LastRunResult + "`r`n" + "`r`n"

if ($out.LastRunResult -ne 0) {
	$outmsg += "The backup job has failed, please investigate" + "`r`n" + "`r`n" 
	$outmsg += "Please document how the situation was rectified in https://katoennatie.sharepoint.com/sites/it/infra/servicedesk/System%20Admins/AVA_Overview.xlsx" + "`r`n"
	$outmsg += "Afterwards document how the situation was rectified as a reply all on this e-mail." + "`r`n"
	$outmsg += "Finally, restart the scheduled task `"Backup DC`" on " + $computername + " followed by the scheduled task `"Backup DC Verify`" when the Backup DC task has finished and check outcome"
	Send-MailMessage -From $from -To $to -Cc $cc -Subject ("[Warning] Backup DC on " + $computername + " has failed") -Body $outmsg -SmtpServer $smtp
	}
	else {
	$outmsg += "The backup job has completed successfully"
    Send-MailMessage -From $from -To $to -Cc $cc -Subject ("[Info] Backup DC on " + $computername + " has completed successfully") -Body $outmsg -SmtpServer $smtp
}