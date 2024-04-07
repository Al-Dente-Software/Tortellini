<#
    .SYNOPSIS
    Makes Unreal Builds and Steam uploads easier

    .EXAMPLE
    PS>$env:STEAM_PASSWORD = my_super_secret_password
    PS>./script/build.ps1 -SteamUpload -SteamUsername myusername

    .EXAMPLE
    PS>./script/build.ps1

    .EXAMPLE
    PS>./script/build.ps1 -LocalGameBuild -Configuration Shipping
    
    .LINK
    https://github.com/Al-Dente-Software/Tortellini
#>

param(
    [Parameter()] # Specifies the configuration to build with, defaults to Development
    [String]$Configuration = "Development", 
    [Parameter()] # Specify the UProject file to use, only required if your project file is not in Tortellini's parent directory
    [String]$Project = "",
    [Parameter()] # Target to use for game builds (SteamUpload, LocalGameBuild). Only required if Tortellini is guessing incorrectly.
    [String]$GameTarget = "",
    [Parameter()] # Target to use for editor builds (SteamUpload, LocalGameBuild). Only required if Tortellini is guessing incorrectly.
    [String]$EditorTarget = "",
    [Parameter()] # VDF file to use for steam upload. 
    [String]$SteamBranch = "",
    [Parameter()] # Usename to use for Steam upload, password must be set in $env:STEAM_PASSWORD
    [String]$SteamUsername = "",
    [Parameter()] # Runs a build and uploads to steam
    [switch]$SteamUpload = $False,
    [Parameter()] # Open the editor after building
    [switch]$AndRun = $False,
    [Parameter()] # Pass -Clean to Unreal Automation Tool. Deletes binaries/intermediates.
    [switch]$Clean = $False,
    [Parameter()] # Builds the game locally with the same commands as SteamUpload but doesn't upload to steam. Will open the folder when complete.
    [switch]$LocalGameBuild = $False,
    [Parameter()] # For clang users on Windows, experimental
    [switch]$GenerateClangDatabase = $False,
    [Parameter()] # Runs checks to see if Tortellini was able to detect Unreal/Steam.
    [switch]$Troubleshoot = $False,
    [Parameter()] # :)
    [switch]$Help = $False
)

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$StringGuid
    )
    
    $ObjectGuid = [System.Guid]::empty
    return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid) # Returns True if successfully parsed
}

function GenerateClangDatabase {
    cmd.exe /c "${UnrealFolder}\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe" -mode=GenerateClangDatabase -project="${UProjectPath}" -OutputDir="$PSScriptRoot/../" $EditorTarget $Configuration Win64
}

function CleanBuild {
    cmd.exe /c ""${UnrealFolder}/Engine/Build/BatchFiles/RunUAT.bat" BuildTarget -NoPCH -NoSharedPCH -nop4 -utf8output -project=$UProjectPath -target=$EditorTarget -platform=Win64 -configuration=$Configuration -Clean"
}

function SteamUpload {
    if (!($SteamBranch))
    {
        Write-Host "-SteamBranch must be specified when using -SteamUpload" -ForegroundColor Red
        return;
    }

    if (!($SteamUsername))
    {
        Write-Host "-SteamUsername must be specified when using -SteamUpload, also the STEAM_PASSWORD environment variable must be set" -ForegroundColor Red
        return;
    }
    
    if (!(Test-Path -Path ${PSScriptRoot}\SteamUpload\builder\steamcmd.exe))
    {
        Write-Host "steamcmd was not found at ${PSScriptRoot}\SteamUpload\builder\steamcmd.exe" -ForegroundColor Red
        Write-Host "Download steamcmd from https://partner.steamgames.com/ and place it in ${PSScriptRoot}\SteamUpload" -ForegroundColor Yellow
    }

    cmd.exe /c ""${UnrealFolder}/Engine/Build/BatchFiles/RunUAT.bat" -ScriptsForProject="$UProjectPath" Turnkey -command=VerifySdk -platform=Win64 -UpdateIfNeeded -project=$UProjectPath BuildCookRun -NoPCH -NoSharedPCH -DisableUnity -nop4 -utf8output -nocompileeditor -skipbuildeditor -cook -project="$UProjectPath" -target=$GameTarget -platform=Win64 -stage -archive -package -build -pak -iostore -compressed -prereqs -archivedirectory="${PSScriptRoot}\..\Binaries" -clientconfig=$Configuration"
    if ($LASTEXITCODE -eq 0) {
        robocopy "${PSScriptRoot}\..\Binaries\Windows" "${PSScriptRoot}\SteamUpload\content" /MIR
        Write-Host "Uploading to $SteamBranch"
        & ${PSScriptRoot}\SteamUpload\builder\steamcmd.exe +login $SteamUsername $env:STEAM_PASSWORD +run_app_build "${PSScriptRoot}\SteamUpload\${SteamBranch}.vdf" +quit
    }
}

function LocalGameBuild {
    cmd.exe /c ""${UnrealFolder}/Engine/Build/BatchFiles/RunUAT.bat" -ScriptsForProject="$UProjectPath" Turnkey -command=VerifySdk -platform=Win64 -UpdateIfNeeded -project=$UProjectPath BuildCookRun -NoPCH -NoSharedPCH -DisableUnity -nop4 -utf8output -nocompileeditor -skipbuildeditor -cook -project="$UProjectPath" -target=$GameTarget -platform=Win64 -stage -archive -package -build -pak -iostore -compressed -prereqs -archivedirectory="${PSScriptRoot}\..\Binaries" -clientconfig=$Configuration"
    if ($LASTEXITCODE -eq 0) {
        explorer "${PSScriptRoot}\..\Binaries\Windows"
    }
}

function Get-UProjectPath {
    if($Project)
    {
        # If -Project specified, use that if the file exists.
        if(!(Test-Path -Path $Project))
        {
            Write-Error "Cannot find $Project"
            return;
        }
    
        return (Get-ChildItem -Path $Project)
    }
    else
    {
        # If -Project is not specified, check ../ for a single UProject file and use that.
        $UProjectFiles = Get-ChildItem $PSScriptRoot/../ -Filter *.uproject
        if ($UProjectFiles.Count -gt 1 -and !$Project)
        {
            Write-Host "Multiple uproject files found, please specify which file to use with -Project" -ForegroundColor Red
            return;
        }

        if ($UProjectFiles.Count -eq 0 -and !$Project)
        {
            $UProjectSearchLocation = Get-Item $PSScriptRoot/../
            Write-Host "No uproject files found in $UProjectSearchLocation, either move your Scripts directory or specify which file to use with -Project" -ForegroundColor Red
            return;
        }

        return $UProjectFiles[0]
    }    
}

function Get-EnginePath {
    $uproject = (Get-UProjectPath).FullName
    $UProjectFile = Get-Content $uproject -Raw | ConvertFrom-Json
    if (-Not $UProjectFile.EngineAssociation)
    {
        Write-Error "Engine association in UProject file is empty, no idea where to find the engine or what version we are using"
        return;
    }

    $UnrealFolder = ""
    if (Test-Path -Path "$PSScriptRoot\.enginepath")
    {
        Write-Verbose "Found .enginepath"
        $UnrealFolder = Get-Content -Path "$PSScriptRoot\.enginepath"
        Write-Verbose "Using engine path: $UnrealFolder"
        return $UnrealFolder
    }

    if (Test-IsGuid -StringGuid $UProjectFile.EngineAssociation)
    {
        Write-Verbose "Looks like engine association is a guid, which means we can try to look it up in registry"
        $UnrealFolder = (Get-ItemProperty -Path 'HKCU:\Software\Epic Games\Unreal Engine\Builds')."$($UProjectFile.EngineAssociation)"
        Write-Verbose "Grabbed Unreal Folder from registry: $UnrealFolder"
    }
    else 
    {
        Write-Verbose "Engine association isn't a guid, but it is set to something, assuming it's a version number like 5.1, 5.3, etc."
        $EngineVersion = $UProjectFile.EngineAssociation
        Write-Verbose "Searching for Epic Games Launcher Unreal Engine InstalledDirectory registry key"

        if (!(Test-Path -Path "HKLM:\Software\EpicGames\Unreal Engine\$EngineVersion"))
        {
            Write-Host "Could not find a registry key in HKLM:\Software\EpicGames\Unreal Engine that matches the engine version specified in the UProject"  -ForegroundColor Red
            Write-Host "EngineVersion: $EngineVersion" -ForegroundColor Yellow
            
            Write-Verbose "Engine installations found in registry:" -ForegroundColor Yellow
            $installations = Get-ChildItem -Path "HKLM:\Software\EpicGames\Unreal Engine\"
            foreach($install in $installations)
            {
                $version = $install.PSChildName
                $engineLocation = (Get-ItemProperty -Path "HKLM:\Software\EpicGames\Unreal Engine\$version").InstalledDirectory
                Write-Verbose "$version - $engineLocation" -ForegroundColor Yellow
            }
        }
        else
        {
            $UnrealFolder = (Get-ItemProperty -Path "HKLM:\Software\EpicGames\Unreal Engine\$EngineVersion").InstalledDirectory
            Write-Verbose "Using engine path: $UnrealFolder"
        }
    }

    return $UnrealFolder
}

function Troubleshoot {
    Write-Host "Running Troubleshoot..."

    $UnrealFolder = Get-EnginePath
    Write-Separator
    Write-Host "Assumptions:" -ForegroundColor Yellow
    $GameTarget = (Get-UProjectPath).BaseName
    $EditorTarget = "${GameTarget}Editor"
    Write-Host "Editor Target: $EditorTarget"
    Write-Host "Game Target: $GameTarget"
    Write-Host "If these targets are not right, you need to pass in -GameTarget and/or -EditorTarget" -ForegroundColor Yellow
    Write-Host "At least until Tortellini is smart enough to get this info automatically..." -ForegroundColor Yellow
    Write-Separator
    Write-Host "Checking if RunUAT.bat exists where we expect it: ${UnrealFolder}\Engine\Build\BatchFiles\RunUAT.bat"
    if (Test-Path -Path ${UnrealFolder}\Engine\Build\BatchFiles\RunUAT.bat)
    {
        Write-Host "Tortellini was able to find an unreal installation" -ForegroundColor Green
    }
    else 
    {
        Write-Host "Couldn't find RunUAT.bat in the engine folder" -ForegroundColor Red       
        Write-Host "If you are desperate to get this working as a band-aid you can add the path to the engine folder in $PSScriptRoot\.enginepath and re-run -Troubleshoot" -ForegroundColor Red
    }

    Write-Separator
    Write-Host "Checking for steamcmd, which is required to use the -SteamUpload flag"
    if (!(Test-Path -Path ${PSScriptRoot}\SteamUpload\builder\steamcmd.exe))
    {
        Write-Host "steamcmd was not found at ${PSScriptRoot}\SteamUpload\builder\steamcmd.exe" -ForegroundColor Red
        Write-Host "Download steamcmd from https://partner.steamgames.com/ and place it in ${PSScriptRoot}\SteamUpload" -ForegroundColor Red
    }
    else 
    {
        Write-Host "steamcmd was found!" -ForegroundColor Green
    }

    Write-Host "Checking for vdf file"
    $files = Get-ChildItem -Path ${PSScriptRoot}\SteamUpload -Filter *.vdf
    if ($files.Length -eq 0)
    {
        Write-Host "Could not find any vdf files."
    }
    foreach($file in $files)
    {
        Write-Host "Found steam branch: $file"
    }
}

function Build-Editor {
    cmd.exe /c ""${UnrealFolder}/Engine/Build/BatchFiles/RunUAT.bat" BuildTarget -nop4 -utf8output -project=$UProjectPath -target=$EditorTarget -platform=Win64 -configuration=$Configuration"
}

function Write-Separator {
    $separator = "#" * (Get-Host).UI.RawUI.MaxWindowSize.Width
    Write-Host $separator
}

$bannerWide = @"
_________  ________  ________  _________  _______   ___       ___       ___  ________   ___     
|\___   ___\\   __  \|\   __  \|\___   ___\\  ___ \ |\  \     |\  \     |\  \|\   ___  \|\  \    
\|___ \  \_\ \  \|\  \ \  \|\  \|___ \  \_\ \   __/|\ \  \    \ \  \    \ \  \ \  \\ \  \ \  \   
     \ \  \ \ \  \\\  \ \   _  _\   \ \  \ \ \  \_|/_\ \  \    \ \  \    \ \  \ \  \\ \  \ \  \  
      \ \  \ \ \  \\\  \ \  \\  \|   \ \  \ \ \  \_|\ \ \  \____\ \  \____\ \  \ \  \\ \  \ \  \ 
       \ \__\ \ \_______\ \__\\ _\    \ \__\ \ \_______\ \_______\ \_______\ \__\ \__\\ \__\ \__\
        \|__|  \|_______|\|__|\|__|    \|__|  \|_______|\|_______|\|_______|\|__|\|__| \|__|\|__|
                                                                                                    
                    https://github.com/Al-Dente-Software/Tortellini

"@

$bannerSmall = @"
Tortellini - https://github.com/Al-Dente-Software/Tortellini

"@

if ((Get-Host).UI.RawUI.MaxWindowSize.Width -gt 96)
{
    Write-Host $bannerWide
}
else
{
    Write-Host $bannerSmall
}

Write-Separator

if ($Help)
{
    Get-Help -Detailed $PSScriptRoot/build.ps1
    return;
}

$UProjectPath = (Get-UProjectPath).FullName
if (!$UProjectPath)
{
    return;
}

if (!($GameTarget))
{
    $GameTarget = (Get-UProjectPath).BaseName
}

if (!($EditorTarget))
{
    $EditorTarget = "${GameTarget}Editor"
}

if ($Troubleshoot)
{
    Troubleshoot
    return;
}

$UnrealFolder = Get-EnginePath
Write-Verbose "Running with configuration $Configuration"
Write-Separator

if ($LocalGameBuild) {
    LocalGameBuild
}
elseif ($SteamUpload) {
    SteamUpload
}
elseif ($Clean) {
    CleanBuild
}
elseif ($GenerateClangDatabase) {
    GenerateClangDatabase
}
else {
    Build-Editor
}

if($AndRun)
{
    & $UProjectPath
}
