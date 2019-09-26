<#

.DESCRIPTION
   A build script that can be included in TFS that update the versions of the dependencies in the '*.nuspec' file from the 'packages.config' file.

.EXAMPLE
   NuspecAutoUpdate.ps1 -NuspecPath "myPackage.nuspec" -PackagesConfigPath "packages.config"
.EXAMPLE
   NuspecAutoUpdate.ps1 -NuspecPath "C:\CCT\main\API\API\Cytra.API.nuspec" -PackagesConfigPath "C:\CCT\main\API\API\packages.config"
#>

Param
(
    # The path to the *.nuspec file.
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$NuspecPath,

    # The path to the packages.config file.
    [Parameter(Mandatory=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$PackagesConfigPath
)

$ErrorActionPreference = "Stop"; #Make all errors terminating

function ReadXmlContent($filePath)
{
    try {
        [xml]$xmlContent = Get-Content $filePath;
        return $xmlContent;
    }
    catch {
        Write-Host "Failed to read file : $filePath";
        Write-Host $Error[0].Exception;
        exit 1;
    }
}

# Reading all packages name & version from the "packages.Config" file
Write-Host "`nReading all packages name & version from the 'packages.Config' file";
$packagesDictionary = @{};
$packagesConfigXml = ReadXmlContent $PackagesConfigPath;

foreach($packageEntry in $packagesConfigXml.packages.package)
{
    $packagesDictionary[$packageEntry.id] = $packageEntry.version;
}


# ReWrite the new version in the nuspec file.
Write-Host "ReWrite the new version in the nuspec file.";
$changesWhereMade = $False;
$versionRegex = [regex]"[0-9a-z]+(.[0-9a-z]+)*";
$nuspecXml = ReadXmlContent $NuspecPath;
foreach($targetFrameworkGroup in $nuspecXml.package.metadata.dependencies.group)
{
    Write-Host "";
    Write-Host "Processing dependency group: $($targetFrameworkGroup.targetFramework)";
    foreach($dependencyEntry in $targetFrameworkGroup.dependency)
    {
        $dependencyID = $($dependencyEntry.id);

        $dependencyExistInPackageConfig = $packagesDictionary.ContainsKey($dependencyID);
        if($dependencyExistInPackageConfig)
        {
            # We want to get the ' $versionFromConfigFile' and put it in the current '$dependencyEntry'.
            $versionFromConfigFile = $($packagesDictionary[$dependencyID]);
            $oldVersion = $($dependencyEntry.version);

            #Notice: the fullNewVersion include "[ ] ( ) ," chars that doesn't exist in the package config file.
            $fullNewVersion = $versionRegex.replace($oldVersion, $versionFromConfigFile, 1);
            if($dependencyEntry.version -ne $fullNewVersion)
            {
                $dependencyEntry.version = $fullNewVersion;
                $changesWhereMade = $True;
            }
        
            Write-Host "Dependency ID: $dependencyID , Old version: $oldVersion , New version: $fullNewVersion";
        }
		else
		{
			 Write-Host "Dependency ID: $dependencyID Removed";
			 $dependencyEntry.ParentNode.RemoveChild($dependencyEntry);
			 $changesWhereMade = $True;
		}
    }
    Write-Host "";
}

if($changesWhereMade)
{
    Write-Host "Saving the new data in the original nuspec file.";
    $nuspecXml.Save($NuspecPath);
}
else
{
    Write-Host "All packages versions are up-to-date, no need to update the original nuspec file.";
}

Write-Host "Nuspec Auto Update Script Completed.";
