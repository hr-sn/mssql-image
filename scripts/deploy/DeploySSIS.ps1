## ==========================================================================
## Author	: H Saini
## References: http://www.mattmasson.com/index.php/2012/06/publish-to-ssis-catalog-using-powershell/
## Purpose	: 	1. Deploy .ispac file to SSIS catalog
##				2. Configure project to use specific environment
## Pre-Requiste: SSISDB configured
## Created	: 2013-01-29
## TODO		: 
## Modification History:
## Date			Version	Name				Comments
## ---------------------------------------------------------------------------
## 20130722		1.1		H Saini		Added $Version Param to input and logic
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
#$pathVersion = $path + (Split-Path $Version -Leaf).Replace(".xml", "") + "\"
## Get Environment constants/variables
#$envVarFile = $pathVersion + $Config
$envVarFile = "..\..\releases\$Version\" + $Config
$pathSSIS = "..\..\releases\$Version\"
##
Write-Host "pathSSIS is $pathSSIS"

if (Test-Path $envVarFile) 
{
	[xml]$xmlVarFile = Get-Content $envVarFile
	try
	{
		foreach ($nodes in $xmlVarFile.SelectNodes("//settings"))
		{
			## Environment constants
			$environmentName = $nodes.environmentname.get_InnerText()
			$folderName = $nodes.foldername.get_InnerText()
			$folderDescription = $nodes.folderdescription.get_InnerText()
			$server = $nodes.server.get_InnerText()
		}
		$constr = "Data Source=" + $server + ";Initial Catalog=master;Integrated Security=SSPI;encrypt=false" #Connection string to Target SQL Server 
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
	$cat = $ssis.Catalogs["SSISDB"]
	$folder = $cat.Folders[$folderName]
}
catch
{
	Write-Host "Failed to setup SSIS instance .. exiting"
	return
}

$projectFiles = Get-ChildItem $pathSSIS -Recurse -Include *.ispac
foreach ($file in $projectFiles)
{
	## Deploy project
	$projectName = $file.Name.Replace(".ispac", "")
	Write-Host "Deploying project .. " $projectName
	try
	{
		[Byte[]] $projectFile = [System.IO.File]::ReadAllBytes($file.FullName)
		## output redirect to $null to make deploy silent
		$null = $folder.DeployProject($projectName, $projectFile)		
	
		$project = $folder.Projects[$projectName]
		if (-not $project.References.Contains($environmentName, $folder.Name))
		{
			Write-Host "Adding environment"
			## Add reference to environment if doesn't exist
			$project.References.Add($environmentName, $folder.Name)
			$project.Alter()
		}
		
		## Configure project parameters to read values from environment variables
		Write-Host "Mapping project parameters"
		foreach ($param in $project.Parameters)
		{
			if ([bool]$param.Required)
			{
#				Write-Host $param.ReferencedVariableName
				## Syntax to set value of parameter is param.set(<type>, <envVariable>
				## $param.Name is used because in our case name of environment variable is same as project parameter
				$param.set("Referenced", $param.Name)		
			}
		}
		$project.Alter()
	}
	catch
	{
		Write-Host "Error deploying/configuring project:" $projectName $Error[0]
	}
	Write-Host "Project deployed successfully..." $projectName
}