### Get windows server core images
docker pull mcr.microsoft.com/windows/servercore:ltsc2019

## download offline media for SQL Server Developer Edition and have it available locally, in this example, it's available at c:\temp\sqlinstall
## how to create offline media? Follow this link https://andyleonard.blog/2022/11/download-sql-server-2022-developer-edition/
## once ISO image is available, mount it and copy the content out to c:\temp\sqlinstall (this location is only for example, you can choose whatever)
## Start docker container and map the c:\temp as drive into container, so we can install SQL DB and IS
##ping command is added, so the container stays alive. You might find it's not required
docker run -d -p 1433:1433 --name mySql -m 2048M -v c:\temp\:c:\users\public\downloads mcr.microsoft.com/windows/servercore:ltsc2019 ping localhost -t

## initiate remote powershell connection
docker exec -it mySql powershell

$Secure = Read-Host -AsSecureString
$up3r$3cr3t9436@1!

./setup.exe /Q /SUPPRESSPRIVACYSTATEMENTNOTICE /IACCEPTSQLSERVERLICENSETERMS /ACTION="install" /FEATURES=SQL,IS /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=$Secure /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /SQLSVCACCOUNT="NT Service\MSSQLSERVER" /AGTSVCACCOUNT="NT Service\SQLSERVERAGENT" /ISSVCACCOUNT="NT Service\MsDtsServer160" /SQLSVCSTARTUPTYPE="Automatic" /ISSVCSTARTUPTYPE="Automatic"  /TCPENABLED=1 /INDICATEPROGRESS

## creating a container from image
docker run -d -p 1433:1433 --name mySql -m 2048M -v c:\temp:c:\users\public\downloads windows-core-with-sql-is

## starting a container

## stopping a container
docker stop mySql


## download dotnet-install.ps1 from https://learn.microsoft.com/en-us/dotnet/core/install/windows#install-with-powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
## we need to install dotnet twice, first one will install 
.\dotnet-install.ps1 -Architecture x64 -InstallDir "C:\Program Files\dotnet\"
dotnet-install.ps1 -Architecture x64 -InstallDir "C:\Program Files\dotnet\" -Runtime dotnet

## installed in this path, you will need to add this to path manually "C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet\"
## exec 'dotnet' from PowerShell, if fails then path is missing
## check path
echo $env:path
$env:path += '; C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet\;C:\users\ContainerAdministrator\.dotnet\tools\'
## don't use below command, require to add old path as well
[Environment]::SetEnvironmentVariable("path","C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet\","Machine")

md c:\packages
cd c:\packages
dotnet new nugetconfig 

dotnet nuget config set globalPackagesFolder "C:\packages"
dotnet tool install -g microsoft.sqlpackage

### Check dot net version
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | 
    Where-Object { $_.PSChildName -Match '^(?!S)\p{L}'} | 
    Select-Object PSChildName, version