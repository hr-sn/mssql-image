## ==========================================================================
## Author	: H Saini
## References: https://learn.microsoft.com/en-us/sql/integration-services/catalog/ssis-catalog?view=sql-server-ver16
## Purpose	: 	1. Create SSISDB/Catalog
##				2. Create environment
##				3. Create variables in environment
## Pre-Requiste: CLR Enabled on Target SQL Server
## Created	: 2012-12-04
## TODO		: 
## To Enable CLR use below code
## sp_configure 'show advanced options', 1;
## GO
## RECONFIGURE;
## GO
## sp_configure 'clr enabled', 1;
## GO
## RECONFIGURE;
## GO
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

$path = (Join-Path (Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path)"")
$pathVersion = $path + (Split-Path $Version -Leaf).Replace(".xml", "") + "\"
$envVarFile = "..\..\releases\$Version\" + $Config

## Get Environment constants/variables
if (Test-Path $envVarFile) 
{
	Write-Host "Reading config file [$($envVarFile)]"
	[xml]$xmlVarFile = Get-Content $envVarFile
	try
	{
		foreach ($nodes in $xmlVarFile.SelectNodes("//settings"))
		{
			## Environment constants
			$environmentName = $nodes.environmentname.get_InnerText()
			$environmentDescription = $nodes.environmentdescription.get_InnerText()
			$enable_clr = [int] $nodes.enable_clr.get_InnerText()	
			
			$folderName = $nodes.foldername.get_InnerText()
			$folderDescription = $nodes.folderdescription.get_InnerText()
			$server = $nodes.server.get_InnerText()
			$dropExistingCatalog = [int] $nodes.dropexistingcatalog.get_InnerText()
			$password = $nodes.passwordforcatalog.get_InnerText()
		}
		$constr = "Data Source=" + $server + ";Initial Catalog=master;Integrated Security=True;;encrypt=false" #Connection string to Target SQL Server 
	}
	catch
	{
		Write-Host "Cannot read xml file: $envVarFile ... exiting"
		return
	}
}
else
{
	Write-Host "Couldn't find config file: $envVarFile ... exiting"
	return
}

## enable clr, if required
if ($enable_clr -eq 1)
{
	try
	{
		Invoke-Sqlcmd -ConnectionString:$constr -Query:"sp_Configure @Configname=clr_enabled,@configvalue=1;"
		Invoke-Sqlcmd -ConnectionString:$constr -Query:"RECONFIGURE;"
	}
	catch
	{
		Write-Host "Failed to enable clr on $server... exiting"
		return
	}
}


## setup instance
try
{
	# Store the IntegrationServices Assembly namespace to avoid typing it every time
	$ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"  
	# Load the IntegrationServices Assembly            
	$loadStatus = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices")
	# Create a connection to the server            
	$con = New-Object System.Data.SqlClient.SqlConnection $constr            
	            
	# Create the Integration Services object            
	$ssis = New-Object $ISNamespace".IntegrationServices" $con
#	$ssis.GetType()
}
catch
{
	Write-Host $Error[0] + "Failed to setup instance on $server .. exiting"
	return
}

# Drop the existing catalog if it exists 
if (($dropExistingCatalog -eq 1) -and ($ssis.Catalogs.Count -gt 0))
{
	Write-Host "Removing existing SSISDB catalog ..."            
	$ssis.Catalogs["SSISDB"].Drop()
	Write-Host "Existing SSISDB removed ..."
}

if ($ssis.Catalogs.Count -eq 0)		#SSIDB doesn't exist, create one
{
	# Provision a new SSIS Catalog            
	Write-Host "Creating new SSISDB Catalog ..."
	try
	{
		$cat = New-Object $ISNamespace".Catalog" ($ssis, "SSISDB", $password)            
		$cat.Create() 
		Write-Host "SSISDB created ..."
	}
	catch 
	{
		Write-Host "Error when creating SSISDB \n" + $Error[0]
		return 
	}
}
else
{
	$cat = $ssis.Catalogs["SSISDB"]
	Write-Host "SSISDB already exists ..."
}

try
	{
	if ($cat.Folders.Contains($folderName))		# Check if folder already exists
	{
		Write-Host "Folder already exists ..."
		
		# Load folder to object
		$folder = $cat.Folders[$folderName]
		
		#	# Below code for debugging only
		#	foreach ($fld in $cat.Folders)
		#	{
		#		Write-Host $fld.Name
		#		#$cat.Folders["BI"].
		#	}
	}
	else
	{
		# Provision to create folder
		$folder = New-Object $ISNamespace".CatalogFolder" ($cat, $folderName, $folderDescription)
		$folder.Create()
		Write-Host $folder.Name " created ..."
	}
}
catch
{
	Write-Host "Error creating " $folderName $Error[0]
}

## configure environment
try
{
	if ($folder.Environments.Contains($environmentName))
	{
		Write-Host "Deleting existing environment ..."
		$folder.Environments[$environmentName].Drop()
	}

	# Provision to create environment
	$environment = New-Object $ISNamespace".EnvironmentInfo" ($folder, $environmentName, $environmentDescription) 
	$environment.Create() 
	Write-Host "Environmment:" $environment.Name " created in folder:" $folder.Name " ..."
}
catch
{
	Write-Host "Error creating Environment: " $environmentName $Error[0]
}

try
{
	## Read variable nodes
	$variableNodes = $xmlVarFile.SelectNodes("//variables/variable")
	foreach ($node in $variableNodes)
	{
		# Adding variables to environment
		# Constructor args: variable name, type, default value, sensitivity, description
		$environment.Variables.Add($node.name, $node.type, $node.value,[bool] [int] $variable.sensitivity , $node.description)
	}
	$environment.Alter()
	Write-Host "Environmment:" $environmentName " successfully configured with variables ..."
}
catch
{
	Write-Host "Error configuring Environmment:" $environmentName $Error[0]
}


