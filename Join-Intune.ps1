<#
This script joins a device to Intune that has already been joined to Azure AD.

Before running the script, ensure the following:
- Device user has a Microsoft license that includes Intune. https://learn.microsoft.com/en-us/mem/intune/fundamentals/licenses
- Device user is a member of a security group enabled for automatic MDM enrollment (added to the MDM user scope). https://learn.microsoft.com/en-us/mem/intune/enrollment/windows-enroll
- Device is joined to Azure AD.

After running the script, have the device online and awake with the user signed in, and allow a few hours for the enrollment to take effect (in the case that the initial enrollment attempt does not succeed).

For troubleshooting help, see this article:
https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-auto-enrollment

The way the script works is by replicating the effects of enabling the group policy called "Enable automatic MDM enrollment using default Azure AD credentials".
  - Policy can be found in Administrative Templates\Windows Components\MDM

1. Creates a registry entry at Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM
    - Name: AutoEnrollMDM
    - Value: 1
2. Creates a scheduled task titled "Schedule created by enrollment client for automatically enrolling in MDM from Azure Active Directory."
    - Task can be found at the root level of task scheduler when created by the script. If created by group policy, it will be found in Microsoft\Windows\EnterpriseMgmt.

It also starts an enrollment attempt before the scheduled task is run, but this only works when the script is ran in the system context (i.e with Absolute, an RMM, or PSEXEC).
#>

# functions
function Set-AutomaticMDMEnrollment
{
  Set-AutoEnrollmentRegistryEntry
  Set-MDMEnrollmentScheduledTask
  gpupdate /force
}

function Set-AutoEnrollmentRegistryEntry
{
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\" -Name MDM -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM" -Name AutoEnrollMDM -Value 1 -ErrorAction SilentlyContinue | Out-Null
}

function Set-MDMEnrollmentScheduledTask
{
  $scheduledTaskName = "Schedule created by enrollment client for automatically enrolling in MDM from AAD"
  $date = Get-Date -Format "yyyy-MM-dd"
  $timeIn5Min = (Get-date).AddMinutes(5).ToString("HH:mm:ss")
  $scheduledTaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Microsoft Corporation</Author>
    <URI>\Microsoft\Windows\EnterpriseMgmt\Schedule created by enrollment client for automatically enrolling in MDM from AAD</URI>
    <SecurityDescriptor>D:P(A;;FA;;;BA)(A;;FA;;;SY)(A;;FRFX;;;LS)</SecurityDescriptor>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>P1D</Duration>
        <StopAtDurationEnd>true</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$($date)T$($timeIn5Min)</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>Queue</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>%windir%\system32\deviceenroller.exe</Command>
      <Arguments>/c /AutoEnrollMDM</Arguments>
    </Exec>
  </Actions>
</Task>
"@

  Register-ScheduledTask -XML $scheduledTaskXML -TaskName $scheduledTaskName -Force | Out-Null
}

function Start-EnrollmentAttempt
{
  Set-EnrollmentURLsInRegistry

  # This only works when ran in the system context (as opposed to user context). For example, with the scheduled task, Absolute, an RMM, or PSEXEC.
  C:\Windows\system32\deviceenroller.exe /c /AutoEnrollMDM 
}

function Set-EnrollmentURLsInRegistry
{
  $path = 'SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\*'
  $keyInfo = Get-Item "HKLM:\$path"
  $tenantID = ($keyInfo.name).Split("\")[-1]
  $path = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\$tenantID"

  # These entries are most likely there already, but we'll set them just in case.
  New-ItemProperty -LiteralPath $path -Name 'MdmEnrollmentUrl' -Value 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc' -PropertyType String -Force -ErrorAction SilentlyContinue
  New-ItemProperty -LiteralPath $path  -Name 'MdmTermsOfUseUrl' -Value 'https://portal.manage.microsoft.com/TermsofUse.aspx' -PropertyType String -Force -ErrorAction SilentlyContinue
  New-ItemProperty -LiteralPath $path -Name 'MdmComplianceUrl' -Value 'https://portal.manage.microsoft.com/?portalAction=Compliance' -PropertyType String -Force -ErrorAction SilentlyContinue
}

# main
Set-AutomaticMDMEnrollment
Start-EnrollmentAttempt