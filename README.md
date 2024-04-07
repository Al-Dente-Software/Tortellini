# Tortellini - A simple and portable wrapper for Unreal Builds and Steam Uploads

## Overview

Tortellini is meant to be a simple and portable wrapper for Unreal Builds and Steam Uploads. It is meant to be copied into any Unreal project and "just work". It is not meant to provide the optimal setup or best set of arguments for Unreal builds, it is meant to get you up and running quickly.

## Requirements

- Unreal Engine must be installed either through the Epic games launcher, installed build, or a source build.
- Your UProject file must have an `EngineAssociation` field set ([Unreal Docs](https://docs.unrealengine.com/4.26/en-US/API/Runtime/Projects/FProjectDescriptor/EngineAssociation/))

## Setup Instructions

- Make a `Scripts` folder at the root of your Unreal project (probably next to your UProject file) and clone/copy this repo into it.
- Download Steamworks SDK (steamcmd) from <https://partner.steamgames.com/>, extract it, and copy `sdk\tools\ContentBuilder\builder\steamcmd.exe` to `SteamUpload\builder\steamcmd.exe`
- Run `./Scripts/build.ps1 -Troubleshoot` to see if Tortellini can detect everything it needs.

If everything is working properly you should see something like this:

![Troubleshoot output](https://aldentesoftware.com/screenshots/troubleshoot.png)

## Usage

Run `.\Scripts\build.ps1 -Help` to get the latest help info

SYNTAX
    `build.ps1 [[-Configuration] <String>] [[-Project] <String>]
    [[-GameTarget] <String>] [[-EditorTarget] <String>] [[-SteamBranch] <String>] [[-SteamUsername] <String>]
    [-SteamUpload] [-AndRun] [-Clean] [-LocalGameBuild] [-GenerateClangDatabase] [-Troubleshoot] [-Help]
    [-Verbose]`

PARAMETERS
    -Configuration <String>
        Specifies the configuration to build with, defaults to Development

    -Project <String>
        Specify the UProject file to use, only required if your project file is not in Tortellini's parent directory

    -GameTarget <String>
        Target to use for game builds (SteamUpload, LocalGameBuild). Only required if Tortellini is guessing
        incorrectly.

    -EditorTarget <String>
        Target to use for editor builds (SteamUpload, LocalGameBuild). Only required if Tortellini is guessing
        incorrectly.

    -SteamBranch <String>
        VDF file to use for steam upload.

    -SteamUsername <String>
        Usename to use for Steam upload, password must be set in $env:STEAM_PASSWORD

    -SteamUpload [<SwitchParameter>]
        Runs a build and uploads to steam

    -AndRun [<SwitchParameter>]
        Open the editor after building

    -Clean [<SwitchParameter>]
        Pass -Clean to Unreal Automation Tool. Deletes binaries/intermediates.

    -LocalGameBuild [<SwitchParameter>]
        Builds the game locally with the same commands as SteamUpload but doesn't upload to steam. Will open the
        folder when complete.

    -GenerateClangDatabase [<SwitchParameter>]
        For clang users on Windows, experimental

    -Troubleshoot [<SwitchParameter>]
        Runs checks to see if Tortellini was able to detect Unreal/Steam.

    -Help [<SwitchParameter>]
        :)

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216).

## Troubleshooting

Unreal Engine is a complex beast, and builds are no exception. There are certainly scenarios this script doesn't cover. If you are having trouble getting this script working [join our Discord](https://discord.gg/rkJe66NVYb) and post the output of your `-Troubleshoot` in #techsupport

## Linux

A shell script clone is definitely possible and in the works.

## Engine Path Override

This is not required but it is possible to override the engine association auto-detection by putting a file called `.enginepath` next to `build.ps1` with `/path/to/unreal/engine/`. If you run with `-Verbose` you will see that Tortellini picks up that file and will use that path. This can be useful for testing new engine versions without having to change your uproject EngineAssociation.
