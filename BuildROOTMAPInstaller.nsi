!include FileFunc.nsh
!include LogicLib.nsh
!insertmacro GetTime
!include "WordFunc.nsh"

!ifndef SEMVER
    !error "SEMVER not set. Please provide a valid semantic versioning string (without 'v' prefix)."
!endif
!ifndef PRODUCTVERSION
    !error "PRODUCTVERSION not set. Please provide a version string in major.minor.patch format, without prerelease tags."
!endif

Name ROOTMAP
OutFile "InstallROOTMAP-v${SEMVER}.exe"
ShowInstDetails "nevershow"
ShowUninstDetails "nevershow"
RequestExecutionLevel admin ; Admin is required to install VC++ redistributable, add ROOTMAP to Start menu etc.

VIProductVersion                 "${PRODUCTVERSION}.0" ; Note ROOTMAP's versioning scheme is only major.minor.patch. NSIS requires a 4-part version number, so we add .0 to the end.
VIAddVersionKey ProductName      "ROOTMAP"
VIAddVersionKey Comments         ""
VIAddVersionKey CompanyName      "University of Western Australia"
VIAddVersionKey LegalCopyright   "© 2021 University of Western Australia"
VIAddVersionKey FileDescription  "ROOTMAP is a simulation package for modelling root systems."
VIAddVersionKey FileVersion      "${SEMVER}"
VIAddVersionKey ProductVersion   "${SEMVER}"
VIAddVersionKey InternalName     "ROOTMAP"

;--------------------------------
; Folder selection page

InstallDir "$APPDATA\ROOTMAP\v${SEMVER}"

;--------------------------------
; Checks to see if a Visual Studio 2017 C++ Redistributable is installed. If not, downloads and installs the latest. TODO: update to VS2019 C++ redistributable.
Function TryInstallVisualCppRedistributable
Var /GLOBAL EXITCODE
Var /GLOBAL REDIST_INSTALLED

; Tested on 64-bit Windows 10. TODO (important): test on other platforms.
ReadRegStr $REDIST_INSTALLED HKLM "Software\Wow6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" "Installed"

StrCmp $REDIST_INSTALLED 1 already_installed installation_required

already_installed:
    Goto done

installation_required:
    # Save redownloading the redistributable, e.g. if we are reinstalling
    IfFileExists "$TEMP\VC_redist.x86.exe" do_local_install do_network_install

do_local_install:
    # Redistributable installer found on the local disk.  Use this copy
    ExecWait '"$TEMP\VC_redist.x86.exe" /passive /norestart' $EXITCODE
    Goto is_reboot_requested

do_network_install:
    Var /GLOBAL vcRedistDidDownload
    NSISdl::download "https://aka.ms/vs/15/release/VC_redist.x86.exe" "$TEMP\VC_redist.x86.exe" vcRedistDidDownload

    StrCmp $vcRedistDidDownload success fail
    success:
        ExecWait '"$TEMP\VC_redist.x86.exe" /passive /norestart' $EXITCODE
        Goto is_reboot_requested

    fail:
        MessageBox MB_OK|MB_ICONEXCLAMATION "Unable to download Visual C++ Redistributable. Please try again. If still unsuccessful, you can try installing the Redistributable from https://aka.ms/vs/15/release/VC_redist.x86.exe separately, rebooting, then installing ROOTMAP."
        Goto done

# $EXITCODE contains the return codes.  1641 and 3010 means a Reboot has been requested
is_reboot_requested:
    ${If} $EXITCODE = 1641
    ${OrIf} $EXITCODE = 3010
        SetRebootFlag true
    ${EndIf}

#exit the function
done:

FunctionEnd


;--------------------------------
; Installer Section
Section "install"
  ; Get a timestamp for making a backup directory
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6

  ; Install the Visual C++ Redistributable
  Call TryInstallVisualCppRedistributable

  ; Back up the user's configuration directory, if it exists.
  IfFileExists "$INSTDIR\Configurations\*.*" 0 +3
  CreateDirectory "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6\Configurations"
  CopyFiles "$INSTDIR\Configurations" "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6"

  ; Back up the users's raytracing directory, if it exists.
  IfFileExists "$INSTDIR\Raytracing\*.*" 0 +3
  CreateDirectory "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6\Raytracing"
  CopyFiles "$INSTDIR\Raytracing" "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6"

  ; Back up the users's postprocessing directory, if it exists.
  IfFileExists "$INSTDIR\Postprocessing\*.*" 0 +3
  CreateDirectory "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6\Postprocessing"
  CopyFiles "$INSTDIR\Postprocessing" "$INSTDIR\reinstallation_backup_$2$1$0$4$5$6"

  ; Set to only overwrite configuration, documentation etc. if newer.
  ; Don't want to overwrite any changes the user may have made to their config,
  ; unless we've made changes too (which need to be enforced for compatibility reasons).
  SetOverwrite ifnewer

  ; Copy configuration schemata
  SetOutPath "$INSTDIR\Configurations\Schemata"
  File /r "ROOTMAP.Native\Configurations\Schemata\"

  ; Copy the basic config dir to user APPDATA space
  SetOutPath "$INSTDIR\Configurations\default"
  File /r "ROOTMAP.Native\Configurations\default\"

  ; Copy log config files to base data dir
  SetOutPath "$INSTDIR"
  File "ROOTMAP.Native\Configurations\*.cfg"

  ; Copy documentation folder,
  ; raytracing folder and postprocessing folder
  SetOutPath "$INSTDIR\Documentation\"
  File /r "ROOTMAP.Native\Documentation\"
  SetOutPath "$INSTDIR\Postprocessing\"
  File /r "ROOTMAP.Native\Postprocessing\"
  SetOutPath "$INSTDIR\Raytracing\"
  File /r "ROOTMAP.Native\Raytracing\"

  ; Set to overwrite all application files.
  SetOverwrite on

  ; Now, copy all static, unmodifiable application files to app directory
  ; 1. GUI app (ROOTMAP.Native)
  SetOutPath "$INSTDIR\GUI"
  File "ROOTMAP.Native\Release\*.*"
  SetOutPath "$INSTDIR\GUI\resources"
  File /r "ROOTMAP.Native\Release\resources\"

  ; 2. CLI app (ROOTMAP.CLI)
  SetOutPath "$INSTDIR\CLI"
  File "ROOTMAP.CLI\Release\*.*"


  ; Install configuration app
  SetOutPath "$INSTDIR\tools\ConfigurationApp"
  File /r "ROOTMAP.Configurator\App\bin\Release\net6.0-windows\win-x64\publish\"

  ; Copy tools
  SetOutPath "$INSTDIR\tools\ConfigurationImporter"
  File /r "ROOTMAP.Configurator\ConfigurationImporter\ConsoleApp\bin\Release\net6.0\win-x64\publish\"
  SetOutPath "$INSTDIR\tools\SchemaValidator"
  File /r "ROOTMAP.Configurator\SchemaValidator\ConsoleApp\bin\Release\net6.0\win-x64\publish\"
  FileOpen $9 watchconfig.bat w
  FileWrite $9 "RootmapSchemaValidator.exe -p ..\..\Configurations --watch --strict $\r$\n"
  FileClose $9

  ; Set OutPath back to the respective application directories, so shortcuts start in those directory.
  SetOutPath "$INSTDIR\GUI"
  ; TODO: add config-dir argument to this shortcut.
  CreateShortCut "$DESKTOP\ROOTMAP.lnk" "$INSTDIR\GUI\ROOTMAP.exe" ""
  SetOutPath "$INSTDIR\CLI"
  CreateShortCut "$DESKTOP\ROOTMAP CLI v${SEMVER} Command Prompt.lnk" "cmd.exe"

  ; create start-menu items
  CreateDirectory "$SMPROGRAMS\ROOTMAP"
  CreateShortCut "$SMPROGRAMS\ROOTMAP\Uninstall ROOTMAP v${SEMVER}.lnk" "$INSTDIR\GUI\Uninstall.exe" "" "$INSTDIR\GUI\Uninstall.exe" 0
  CreateShortCut "$SMPROGRAMS\ROOTMAP\ROOTMAP v${SEMVER}.lnk" "$INSTDIR\GUI\ROOTMAP.exe" "" "$INSTDIR\GUI\ROOTMAP.exe" 0
  CreateShortCut "$SMPROGRAMS\ROOTMAP\ROOTMAP CLI v${SEMVER} Command Prompt.lnk" "cmd.exe"
  CreateShortCut "$SMPROGRAMS\ROOTMAP\ROOTMAP Configuration App v${SEMVER}.lnk" "$INSTDIR\tools\ConfigurationApp\ROOTMAP.Configurator.exe" "" "$INSTDIR\tools\ConfigurationApp\ROOTMAP.Configurator.exe" 0

  ; write version and path information to the registry
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\ROOTMAP.exe" "" "$APPDATA\ROOTMAP\v${SEMVER}\GUI\ROOTMAP.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\RootmapCLI.exe" "" "$APPDATA\ROOTMAP\v${SEMVER}\CLI\RootmapCLI.exe"

  ; write uninstall information to the registry
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "DisplayName" "ROOTMAP (remove only)"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "UninstallString" "$INSTDIR\GUI\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "Publisher" "University of Western Australia"

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "DisplayVersion" "${SEMVER}"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "NoModify" "1"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}" "NoRepair" "1"

  ; ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  ; IntFmt $0 "0x%08X" $0
  ; WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-${SEMVER}" "EstimatedSize" "$0"

  WriteUninstaller "$INSTDIR\GUI\Uninstall.exe"

  SetAutoClose true
SectionEnd

;--------------------------------
; Uninstaller Section
Section "Uninstall"

  ${If} ${Cmd} 'MessageBox MB_YESNO "ROOTMAP will be uninstalled. Do you wish to keep Configurations, Raytracing and Postprocessing directories?" IDYES'
    MessageBox MB_OK "Uninstalling ROOTMAP. Configurations, Raytracing and Postprocessing directories will be left in $APPDATA\ROOTMAP\v${SEMVER}."
  ${Else}
    ; Delete configuration, raytracing and postprocessing folders.
    RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\Configurations\*.*"
    RMDir "$APPDATA\ROOTMAP\v${SEMVER}\Configurations"
    RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\Raytracing\*.*"
    RMDir "$APPDATA\ROOTMAP\v${SEMVER}\Raytracing"
    RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\Postprocessing\*.*"
    RMDir "$APPDATA\ROOTMAP\v${SEMVER}\Postprocessing"
  ${EndIf}

  ; Delete application files
  RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\GUI\*.*"
  RMDir "$APPDATA\ROOTMAP\v${SEMVER}\GUI"
  RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\CLI\*.*"
  RMDir "$APPDATA\ROOTMAP\v${SEMVER}\CLI"
  ; Delete tools
  RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\tools\*.*"
  RMDir "$APPDATA\ROOTMAP\v${SEMVER}\tools"
  ; Delete documentation files
  RMDir /r "$APPDATA\ROOTMAP\v${SEMVER}\Documentation\*.*"
  RMDir "$APPDATA\ROOTMAP\v${SEMVER}\Documentation"

  ; Delete Start Menu Shortcuts
  Delete "$DESKTOP\ROOTMAP v${SEMVER}.lnk"
  Delete "$SMPROGRAMS\ROOTMAP\ROOTMAP v${SEMVER}.lnk"
  Delete "$DESKTOP\ROOTMAP CLI v${SEMVER} Command Prompt.lnk"
  Delete "$SMPROGRAMS\ROOTMAP\ROOTMAP CLI v${SEMVER} Command Prompt.lnk"
  Delete "$SMPROGRAMS\ROOTMAP\Uninstall ROOTMAP v${SEMVER}.lnk"
  Delete "$SMPROGRAMS\ROOTMAP\ROOTMAP Configuration App v${SEMVER}.lnk"
  RMDir  "$SMPROGRAMS\ROOTMAP"

  ; Delete Registry Entries
  DeleteRegKey HKEY_LOCAL_MACHINE "Software\ROOTMAP-v${SEMVER}"
  DeleteRegKey HKEY_LOCAL_MACHINE "Software\Microsoft\Windows\CurrentVersion\Uninstall\ROOTMAP-v${SEMVER}"
  DeleteRegKey HKEY_LOCAL_MACHINE "Software\Microsoft\Windows\CurrentVersion\App Paths\ROOTMAP.exe"
  DeleteRegKey HKEY_LOCAL_MACHINE "Software\Microsoft\Windows\CurrentVersion\App Paths\RootmapCLI.exe"

  SetAutoClose true
SectionEnd

;--------------------------------
; MessageBox Section

; Function that calls a messagebox when installation finished correctly
Function .onInstSuccess
  ; TODO Add instructions for config app and CLI ROOTMAP.
  MessageBox MB_OK "ROOTMAP v${SEMVER} installed successfully. Use the desktop icon to start the GUI application."
FunctionEnd

Function un.onUninstSuccess
  MessageBox MB_OK "ROOTMAP v${SEMVER} uninstalled successfully."
FunctionEnd
