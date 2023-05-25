# Join-Intune

## Objective
- Joins a device to Intune that has already been joined to Azure AD.

## Procedure
1. Ensure device user has a [Microsoft license that includes Intune](https://learn.microsoft.com/en-us/mem/intune/fundamentals/licenses).
2. Ensure device user is a member of a security group enabled for automatic MDM enrollment (added to the MDM user scope).
    - See article: [Set up automatic enrollment for Windows devices](https://learn.microsoft.com/en-us/mem/intune/enrollment/windows-enroll#enable-windows-automatic-enrollment).
3. Ensure device is joined to Azure AD.
4. Push the Join-Intune script to the device and run it.
5. After running the script, have the device online and awake with the user signed in, and allow a few hours for the enrollment to take effect (in the case that the initial enrollment attempt does not succeed).

## Troubleshooting Intune Enrollment
- See this article: [Troubleshooting Windows 10 Group Policy-based auto-enrollment in Intune](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-auto-enrollment).

## How the script works
The script works by replicating the effects of enabling the group policy called **"Enable automatic MDM enrollment using default Azure AD credentials"**.
  - Policy can be found in **Administrative Templates\Windows Components\MDM**.

1. Creates a registry entry at **Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM**
    - Name: **AutoEnrollMDM**
    - Value: **1**
2. Creates a scheduled task titled **"Schedule created by enrollment client for automatically enrolling in MDM from Azure Active Directory"**.
    - Task can be found at the root level of task scheduler when created by the script. If created by group policy, it will be found in **Microsoft\Windows\EnterpriseMgmt**.
3. It also starts an enrollment attempt before the scheduled task is run, but this only works when the script is ran in the system context (i.e with Absolute, an RMM, or PSEXEC).
