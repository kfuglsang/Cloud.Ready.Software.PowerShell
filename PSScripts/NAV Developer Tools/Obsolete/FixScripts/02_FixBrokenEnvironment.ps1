﻿Import-NAVModules

$Backup = Get-Item C:\BACKUP\Backup.bak
    
$Defaultinstance = get-navserverinstancedetails -ServerInstance NAV

Set-NAVServerInstance -ServerInstance NAV -stop
Set-NAVServerInstance -ServerInstance Navision_main -Stop

Restore-SQLBackupFile `
Set-NAVServerInstance -ServerInstance Navision_main -Start

Sync-NAVTenant -ServerInstance NAV -Mode Sync -Force
Sync-NAVTenant -ServerInstance Navision_main -Mode Sync -Force

Add-NAVEnvironmentCurrentUser -ServerInstance NAV -PermissionSetId SUPER
Get-NAVServerInstance | ft -AutoSize