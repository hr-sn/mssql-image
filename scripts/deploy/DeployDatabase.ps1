## ==========================================================================
## Author	: H Saini
## References: 
## Purpose	: 	1. Pick the list of database to be deployed from the environment xml
##				2. Deploy listed .dacpac files to DB Server
## Pre-Requiste: DB Server available
## Created	: 2014-09-26
## TODO		: 
## Modification History:
## Date			Version	Name				Comments
## ---------------------------------------------------------------------------

## ===========================================================================
[CmdletBinding()]
Param(
  #[Parameter(Mandatory=$True,Position=1)]
  [string]$Version = "v1.0"
  ,
 #[Parameter(Mandatory=$True,Position=2)]
  [string]$Config = "Local.xml"
)
#Clear-Host
#$Version = "v4.0.xml"
#$Config = "Local.xml"

## Get Environment constants/variables
$path = (Join-Path (Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path)"")
#$pathVersion = $path + (Split-Path $Version -Leaf).Replace(".xml", "") + "\"
$envVarFile = "..\..\releases\$Version\" + $Config
$pathDacpac = "..\..\releases\$Version\"
$scripts = "..\..\releases\$Version\Scripts"

if (Test-Path $envVarFile) 
{
	[xml]$xmlVarFile = Get-Content $envVarFile
	try
	{
		foreach ($nodes in $xmlVarFile.SelectNodes("//settings"))
		{
			$dbserver = $nodes.server.get_InnerText()
			# $ssas_server = $nodes.ssas_server.get_InnerText()
			# $environment = $nodes.environmentname.get_InnerText()
			# $sqlpackage_properties = $nodes.sqlpackage_properties.get_InnerText()			##"/Properties:CreateNewDatabase=True"
			# $deploy_dacpac = [int] $nodes.deploy_dacpac.get_InnerText()
			$deploy_dacpacfiles = $nodes.deploy_dacpacfiles
			$sqlpackage_exe = $nodes.sqlpackage_exe.get_InnerText()
			If (Test-Path $sqlpackage_exe) {}
			else
			{
				Write-Host "Please fix location of SqlPackage.exe in config file first... exiting [$($sqlpackage_exe)]"
				return
			}
		}
	}
	catch [System.Exception]
	{
		Write-Host "Error connecting to WSDM files location ... $_.Exception.Message "
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

## Check if any dacpacs to deploy
try
{
	foreach($db in $deploy_dacpacfiles.database)
	{

		$catalogname = $db.catalogname
		$filename = $db.filename
		$properties = $db.dacpacproperties.get_InnerText()
		$variable = $db.dacpacvariable.get_InnerText()
		$deploy = [int] $db.deploy;
		$conn = "Data Source=localhost;Initial Catalog=$($catalogname);Integrated Security=True;encrypt=false"
		if ($deploy -eq 1)
		{
			if (Test-Path "$pathDacpac\$filename")
			{
				$callArgs = 
							@(
								$properties,
								"/Action:Publish",
								"/SourceFile:$pathDacpac\$filename",
								"/TargetConnectionString:$conn"
								)
				$callArgs += $variable.Split("|") 		## Add variables to arguments container
				Write-Host "Deploying ... $catalogname " -ForegroundColor Yellow ;
			    Write-Host $sqlpackage_exe $callArgs -ForegroundColor Yellow ;
				& $sqlpackage_exe $callArgs;			## execute command
			}
			else
			{
				Write-Host "could not find $pathDacpac\$filename for $catalogname" -ForegroundColor DarkRed;
			}
		}
	}
}

catch [System.Exception]
{
	Write-Host "Error deploying Database ... $_ " -ForegroundColor DarkRed;
}