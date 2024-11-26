# escape=`
ARG BASE="ltsc2019"
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-$BASE

ARG DEV_ISO="https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLServer2019-x64-ENU-Dev.iso" `
    EXP_EXE= `
    CU="https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5046365-x64.exe" `
    VERSION="15.0.4405.4" `
    TYPE=
ENV DEV_ISO=$DEV_ISO `
    EXP_EXE=$EXP_EXE `
    CU=$CU `
    VERSION=$VERSION `
    sa_password="ChangeHave2024!@" `
    attach_dbs="[]" `
    accept_eula="Y" `
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password" `
    before_startup="C:\before-startup" `
    after_startup="C:\after-startup"

LABEL org.opencontainers.image.authors="Harish Saini"
LABEL org.opencontainers.image.source="https://github.com/hr-sn/mssql-image"
LABEL org.opencontainers.image.description="An unofficial, unsupported and in no way connected to Microsoft container image for MS SQL Server (forked from tobiasfenster)"
LABEL org.opencontainers.image.version=$VERSION-$TYPE

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator

RUN $ProgressPreference = 'SilentlyContinue'; `
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco feature enable -n allowGlobalConfirmation; `
    choco install --no-progress --limit-output vim 7zip sqlpackage pester; `
    Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1; `
    refreshenv;

RUN if (-not [string]::IsNullOrEmpty($env:DEV_ISO)) { `
        Invoke-WebRequest -UseBasicParsing -Uri $env:DEV_ISO -OutFile c:\SQLServer.iso; `
        mkdir c:\installer; `
        7z x -y -oc:\installer .\SQLServer.iso; `
        .\installer\setup.exe /q /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLEngine,IS /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
        remove-item c:\SQLServer.iso -ErrorAction SilentlyContinue; `
        remove-item -recurse -force c:\installer -ErrorAction SilentlyContinue; `
    }

RUN if (-not [string]::IsNullOrEmpty($env:EXP_EXE)) { `
        Invoke-WebRequest -UseBasicParsing -Uri $env:EXP_EXE -OutFile c:\SQLServerExpress.exe; `
        Start-Process -Wait -FilePath .\SQLServerExpress.exe -ArgumentList /qs, /x:installer ; `
        .\installer\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine,IS /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
        remove-item c:\SQLServerExpress.exe -ErrorAction SilentlyContinue; `
        remove-item -recurse -force c:\installer -ErrorAction SilentlyContinue; `
    } 

RUN $SqlServiceName = 'MSSQLSERVER'; `
    if ($env:TYPE -eq 'exp') { `
        $SqlServiceName = 'MSSQL$SQLEXPRESS'; `
    } `
    While (!(get-service $SqlServiceName -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 5 } ; `
    Stop-Service $SqlServiceName ; `
    $databaseFolder = 'c:\databases'; `
    mkdir $databaseFolder; `
    $SqlWriterServiceName = 'SQLWriter'; `
    $SqlBrowserServiceName = 'SQLBrowser'; `
    Set-Service $SqlServiceName -startuptype automatic ; `
    Set-Service $SqlWriterServiceName -startuptype manual ; `
    Stop-Service $SqlWriterServiceName; `
    Set-Service $SqlBrowserServiceName -startuptype manual ; `
    Stop-Service $SqlBrowserServiceName; `
    $SqlTelemetryName = 'SQLTELEMETRY'; `
    if ($env:TYPE -eq 'exp') { `
        $SqlTelemetryName = 'SQLTELEMETRY$SQLEXPRESS'; `
    } `
    Set-Service $SqlTelemetryName -startuptype manual ; `
    Stop-Service $SqlTelemetryName; `
    $version = [System.Version]::Parse($env:VERSION); `
    $id = ('mssql' + $version.Major + '.MSSQLSERVER'); `
    if ($env:TYPE -eq 'exp') { `
        $id = ('mssql' + $version.Major + '.SQLEXPRESS'); `
    } `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpport -value 1433 ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name LoginMode -value 2; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultData -value $databaseFolder; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultLog -value $databaseFolder; 

RUN if (-not [string]::IsNullOrEmpty($env:CU)) { `
        $ProgressPreference = 'SilentlyContinue'; `
        Write-Host ('Install CU from ' + $env:CU) ; `
        Invoke-WebRequest -UseBasicParsing -Uri $env:CU -OutFile c:\SQLServer-cu.exe ; `
        .\SQLServer-cu.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances ; `
        Start-Sleep -Seconds (6*60) ; `
        $try = 0; `
        while ($try -lt 20) { `
            try { `
                $var = sqlcmd -Q 'select SERVERPROPERTY(''productversion'') as version' -W -m 1 | ConvertFrom-Csv | Select-Object -Skip 1 ; `
                if ($var.version[0] -eq $env:VERSION) { `
                    Write-Host ('Patch done, found expected version ' + $var.version[0]) ; `
                    $try = 21 ; `
                } else { `
                    Write-Host ('Patch seems to be ongoing, found version ' + $var.version[0] + ', try ' + $try) ; `
                } `
            } catch { `
                Write-Host 'Something unexpected happened, try' $try ; `
                Write-Host $_.ScriptStackTrace ; `
            } finally { `
                if ($try -lt 20) { `
                    Start-Sleep -Seconds 60 ; `
                } `
                $try++ ; `
            } `
        } `
        if ($try -eq 20) { `
            Write-Error 'Patch failed' `
        } else { `
            Write-Host 'Successfully patched!' `
        } `
    } `
    remove-item c:\SQLServer-cu.exe -ErrorAction SilentlyContinue; 

WORKDIR c:\scripts
COPY .\start.ps1 c:\scripts\

CMD .\start.ps1
