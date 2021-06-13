@echo off

echo THIS IS THE DEVELOPMENT BUILD SCRIPT. IT REQUIRES A FULL WORKING GIT ENVIRONMENT. DO NOT RUN THIS SCRIPT AS PART OF A CI BUILD - USE build.cmd INSTEAD.

SET config=%1
REM Set build configuration to Debug if not specified.
IF [%1]==[] (
  SET config="Debug"
)

SET ver=%2
REM Extract version number from git tags if not specified.
IF [%2]==[] (
  FOR /F "tokens=* USEBACKQ" %%F IN (`git describe`) DO (
    SET ver=%%F
  )
)

echo Building ROOTMAP projects as version %ver% in %config% configuration.
echo.

echo ################################################################################
echo ########                  Updating all git submodules.                  ########
echo ################################################################################
git submodule update --init --recursive

echo ################################################################################
echo ########                    Building ROOTMAP.CLI.                       ########
echo ################################################################################
pushd ROOTMAP.CLI
nuget restore
pushd ROOTMAP.Core
REM TODO Some kind of check to see if this is necessary?
powershell -File .\Prepare-ROOTMAP-Dependencies.ps1
popd
msbuild ROOTMAP.CLI.sln /p:Configuration=%config% /p:Version=%ver%
popd
echo ################################################################################
echo ########                  Building ROOTMAP.Native.                      ########
echo ################################################################################
pushd ROOTMAP.Native
nuget restore
msbuild ROOTMAP.Native.sln /p:Configuration=%config% /p:Version=%ver%
popd
echo ################################################################################
echo ########                Building ROOTMAP.Configurator.                  ########
echo ################################################################################
pushd ROOTMAP.Configurator\App
call build.cmd %config% %ver%
popd
pushd ROOTMAP.Configurator\ConfigurationImporter
call build.cmd %config% %ver%
popd
pushd ROOTMAP.Configurator\SchemaValidator\ConsoleApp
dotnet build --configuration %config% -p:Version=%ver%
dotnet publish -p:Configuration=%config% -p:Version=%ver% -p:PublishTrimmed=false -p:SelfContained=true --runtime win-x64
popd
