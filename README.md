# ROOTMAP.Installer

This is the umbrella repository which is used to pull together and build all the ROOTMAP components into one shared installer for Windows-based systems.

It has git submodules at [ROOTMAP.CLI](https://github.com/ROOTMAPSimulationModel/ROOTMAP.CLI), [ROOTMAP.Configurator](https://github.com/ROOTMAPSimulationModel/ROOTMAP.Configurator) and [ROOTMAP.Native](https://github.com/ROOTMAPSimulationModel/ROOTMAP.Installer). ROOTMAP.CLI and ROOTMAP.Native also reference [ROOTMAP.Core](https://github.com/ROOTMAPSimulationModel/ROOTMAP.Core) as a submodule.

Each of these can be cloned and built separately, which is the recommended method for working with a ROOTMAP component.

---

## Building in CI suite

Continuous Integration builds are run using `azure-pipelines.yml` on Azure DevOps. This YAML file can be adapted to run builds on different CI platforms if needed. Note that it contains three main flavours of task:

1. Setup/housekeeping (using GitVersion to determine the appropriate version number from git tags, etc.)
2. Building the C++ components (using mainly `msbuild` with some Powershell script calls)
3. Building the .NET Core components (calling `build.cmd`, which invokes `dotnet build` and `dotnet publish` on the subcomponents of ROOTMAP.Configurator)

`BuildROOTMAPInstaller.nsi` is set up to consume the built artifacts of the above pipeline and produce and sign a Windows installer. The Azure DevOps project has been configured with the appropriate certificate and credentials to sign the installer and an Azure storage container to upload the built installer to.

---

## Building on a local development machine

For convenience, the `build-dev.cmd` script can be run on a freshly cloned instance of this repo to automatically build everything. It will not automatically invoke `BuildROOTMAPInstaller.nsi`. Prerequisites for running `build-dev.cmd` are:

* Windows environment
* `git` installed and available on the command line
* `nuget` installed and available on the command line
* `powershell` installed and available on the command line
* .NET Core SDK installed and available on the command line

`build-dev.cmd` can be passed two optional parameters to set the build configuration (Debug or Release) and version number (a semver-compatible number, no leading 'v').

Example:

```
|> build-dev.cmd Release 0.1.2-foo