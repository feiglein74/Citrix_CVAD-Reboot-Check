Add-PSSnapin "Citrix.*" -ErrorAction SilentlyContinue

#clear 

# Festlegen der zu prüfenden Bereitstellungsgruppen
$Global:DESKTOPGROUP = @("DG-TS2019","DG-TS2016-Sage")


# Eventlog-Einträge vorbereiten
$Global:EventLog = New-Object -type System.Diagnostics.Eventlog -argumentlist Application
$Global:EventLog.Source = "Citrix Reboot Check Script"
$EventLog.WriteEntry("Starting scheduled task Citrix Post-Reboot Check Script.","Information","111")

#Funktionsdefinitionen
$FinalCheckDown = 
    {
        param ([string]$member)

        $Global:EventLog = New-Object -type System.Diagnostics.Eventlog -argumentlist Application
        $Global:EventLog.Source = "Citrix Reboot Check Script"
        
        function FinalStart
        {
            $EventLog.WriteEntry("Host " + $member + "is Offline. Start will be initiated!","Information","124")
            New-BrokerHostingPowerAction -MachineName $member -Action TurnOn
        }

        FinalStart $member
    }

$FinalCheckOK = 
    {
        param ([string]$member)

        $Global:EventLog = New-Object -type System.Diagnostics.Eventlog -argumentlist Application
        $Global:EventLog.Source = "Citrix Reboot Check Script"
        
        function FinalRunning
        {
            $EventLog.WriteEntry("Host: " + $member + " is running.","Information","123")
        }
        
        FinalRunning $member
    }


# Schleife um alle Bereitstellungsgruppen abzuarbeiten
foreach ($desktopgroup in $GLOBAL:DESKTOPGROUP)
{
    #Abfrage nach Workern in DG
    $desktopgroupmember = @( Get-BrokerDesktop -DesktopGroupName $desktopgroup | where {$_.InMaintenanceMode -Match "False"} | sort-object -property MachineName )
    
    # Prüfung bzgl laufender VMs
    $i=1
    foreach ($member in $desktopgroupmember) 
    {
        if ($member.PowerState -match "Off") 
        {
            Invoke-Command -ScriptBlock $FinalCheckDown -ArgumentList $member.MachineName
        }
        else
        {
            Invoke-Command -ScriptBlock $FinalCheckOK -ArgumentList $member.MachineName
        }
    }
} 
