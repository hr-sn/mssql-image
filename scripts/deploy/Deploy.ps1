## ==========================================================================
## Author	: H Saini (NEC)
## Purpose	: 	1. Deploy solution to selected environment
## Created	: 2013-05-04
## TODO		: Capture error from child script and fail master script
## Modification History:
## Date			Version	Name				Comments
## ---------------------------------------------------------------------------
## 20130722		1.1		HS (NEC)		Added $Version Param to input and logic
## 20140911		1.2		HS (NEC)		Disable deployment of dacpac(s) except BI_DW
## 20141001		1.3		HS (NEC)		Added logic to call DeployDatabase.ps1 for dacpac deployments
## ===========================================================================
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$Version
   ,
  [Parameter(Mandatory=$True,Position=2)]
   [string]$Config
)
Clear-Host

## Get Environment constants/variables
$path = (Join-Path (Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path)"")
$pathVersion = $path + (Split-Path $Version -Leaf).Replace(".xml", "") + "\"
$envVarFile = $pathVersion + $Config
$scripts = $pathVersion + "Scripts"
$pathDacpac = $pathVersion + "Databases"
if (Test-Path $envVarFile) 
{
	[xml]$xmlVarFile = Get-Content $envVarFile
	try
	{
		foreach ($nodes in $xmlVarFile.SelectNodes("//settings"))
		{
			$dbserver = $nodes.server.get_InnerText()
			$ssas_server = $nodes.ssas_server.get_InnerText()
			$environment = $nodes.environmentname.get_InnerText()
			$sqlpackage_properties = $nodes.sqlpackage_properties.get_InnerText()			##"/Properties:CreateNewDatabase=True"
			$config_ssisdb = [int] $nodes.config_ssisdb.get_InnerText()
			$deploy_ispac = [int] $nodes.deploy_ispac.get_InnerText()
			$deploy_dacpac = [int] $nodes.deploy_dacpac.get_InnerText()
			$deploy_dbscripts  = [int] $nodes.deploy_dbscripts.get_InnerText()
			$deploy_ssas = [int] $nodes.deploy_ssas.get_InnerText()
			$deploy_ssrs = [int] $nodes.deploy_ssrs.get_InnerText()
			$sqlpackage_exe = $nodes.sqlpackage_exe.get_InnerText()
			If (Test-Path $sqlpackage_exe) {}
			else
			{
				Write-Host "Please fix location of SqlPackage.exe in config file first... exiting"
				return
			}
		}
	}
	catch
	{
		Write-Host "Cannot read xml file: $envVarFile ... exiting"
		return
	}
}
else
{
	Write-Host "Couldn't find config xml $envVarFile ... exiting"
	return
}


## Configure SSISDB
if ($config_ssisdb -eq 1)
{
	Write-Host "Configuring SSISDB"
	./ConfigSSISDB.ps1 -Version $Version -Config $Config
}

## Deploy SSIS (ispac) projects
if ($deploy_ispac -eq 1)
{
	./DeploySSIS.ps1 -Version $Version -Config $Config 
}

### Create the databases
if ($deploy_dacpac -eq 1)
{
	If (Test-Path $sqlpackage_exe)
	{
		Write-Host "Creating databases..."
		.\DeployDatabase.ps1 -Version $Version -Config $Config			## v1.3
	}
#		## v1.2 start
#		if (Test-Path "$pathDacpac\BI_Control.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_Control.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_Control;Integrated Security=True" /Variables:BI_Log=BI_Log /Variables:BI_Reload=BI_Reload /Variables:BI_StagingA=BI_StagingA /Variables:BI_StagingB=BI_StagingB /Variables:BI_DW=BI_DW /Variables:DeployData=1 /Variables:ResizePrimaryAndLog=1
#		}
#		if (Test-Path "$pathDacpac\BI_Log.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_Log.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_Log;Integrated Security=True" /Variables:BI_Control=BI_Control /Variables:DeployData=0 /Variables:ResizePrimaryAndLog=1
#		}
#		if (Test-Path "$pathDacpac\BI_Reference.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_Reference.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_Reference;Integrated Security=True" /Variables:DeployData=1 /Variables:ResizePrimaryAndLog=1
#		}
#		if (Test-Path "$pathDacpac\BI_StagingA.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_StagingA.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_StagingA;Integrated Security=True" /Variables:BI_Control=BI_Control /Variables:BI_Reload=BI_Reload /Variables:DeployData=0 /Variables:ResizePrimaryAndLog=1
#		}
#		if (Test-Path "$pathDacpac\BI_StagingB.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_StagingB.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_StagingB;Integrated Security=True" /Variables:BI_StagingA=BI_StagingA /Variables:BI_StagingB=BI_StagingB /Variables:DeployData=1 /Variables:ResizePrimaryAndLog=1
#		}
#		if (Test-Path "$pathDacpac\BI_Reload.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_Reload.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_Reload;Integrated Security=True" /Variables:BI_Control=BI_Control /Variables:BI_StagingA=BI_StagingA /Variables:DeployData=1 /Variables:ResizePrimaryAndLog=1
#		}
#		## v1.2 end
#		if (Test-Path "$pathDacpac\BI_DW.dacpac")
#		{
#			& $sqlpackage_exe $sqlpackage_properties /Action:Publish /SourceFile:"$pathDacpac\BI_DW.dacpac" /TargetConnectionString:"Data Source=$dbserver;Initial Catalog=BI_DW;Integrated Security=True" /Variables:BI_Reload=BI_Reload /Variables:BI_Log=BI_Log /Variables:BI_Reference=BI_Reference /Variables:BI_Control=BI_Control /Variables:DeployData=1 /Variables:ResizePrimaryAndLog=1
#		}
#	}
	else
	{
		Write-Host "Couldn't find sqlpackage.exe, databases not deployed..."
	}
}

#### Create Login, Credential, Proxy, SQL Agent Job, PackageControl
if ($deploy_dbscripts -eq 1)
{
	try
	{
		## Iterate through sql scripts; should be named sequentially
		## Not including environment folder yet
		Get-ChildItem -Path $scripts -Filter *.sql  |
			Foreach-Object  { 
					Write-Host "Executing " $_.fullname; 
					& sqlcmd /S $dbserver -i $_.fullname;
			}
		
		## Iterate through environment specific sql scripts; should be named sequentially
		## Not including environment folder yet
		Get-ChildItem -Path $scripts"\"$environment -Filter *.sql  |
			Foreach-Object  { 
					Write-Host "Executing " $_.fullname; 
					& sqlcmd /S $dbserver -i $_.fullname;
			}
	}
	catch
	{
		Write-Host "Error while executing SQL Scripts " $Error[0]
	}
}

#### Deploy the SSAS Cube
if ($deploy_ssas -eq 1)
{
	$xmlaFiles = gci $pathVersion -Recurse -Include *.xmla
	foreach ($xmlaFile in $xmlaFiles)
	{
		if ($xmlaFile -ne $null)
		{
			Write-Host "Deploying cube " $xmlaFile
			try
			{
				$query = Get-Content ($xmlaFile)

				[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.Xmla") | Out-Null
				[Microsoft.AnalysisServices.xmla.xmlaclient]$xmlac = new-object Microsoft.AnalysisServices.Xmla.XmlaClient 
				$xmlac.Connect( $ssas_server )

				$properties = new-object "System.Collections.Generic.Dictionary``2[[System.String, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089],[System.String, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]"
				$xmlac.Send($query, $properties) 
				$xmlac.Disconnect()
			}
			catch
			{
				Write-Host "Error while deploying cube " $Error[0]
			}
		}
	}
}

## Deploy SSRS objects
if ($deploy_ssrs -eq 1)
{
	.\DeploySSRS.ps1 -Version $Version -Config $Config
}

Write-Host "success"
Read-Host "Enter any key to finish: "