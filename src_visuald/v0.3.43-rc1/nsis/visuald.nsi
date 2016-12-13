;VisualD installation script

; define EXPRESS to add Express Versions to the selection of installable VS versions
; !define EXPRESS

; define CV2PDB to include cv2pdb installation (expected at ../../../cv2pdb/trunk)
!define CV2PDB

; define MAGO to include mago installation (expected at ../../../mago)
!define MAGO

; define DPARSER to include DParser COM server installation (expected at ../bin/Release/DParserCOMServer)
!define DPARSER

; define VDSERVER to include vdserver COM server installation
; !define VDSERVER

; define VDEXTENSIONS to include C# extensions (expected at ../bin/Release/vdextensions)
!define VDEXTENSIONS

;--------------------------------
;Include Modern UI

  !include "MUI2.nsh"
  !include "Memento.nsh"
  !include "Sections.nsh"
  !include "InstallOptions.nsh"

  !include "uninstall_helper.nsh"
  !include "replaceinfile.nsh"

;--------------------------------
;General
  !searchparse /file ../version "#define VERSION_MAJOR " VERSION_MAJOR
  !searchparse /file ../version "#define VERSION_MINOR " VERSION_MINOR
  !searchparse /file ../version "#define VERSION_REVISION " VERSION_REVISION
  !searchparse /file ../version "#define VERSION_BETA " VERSION_BETA
  !searchparse /file ../version "#define VERSION_BUILD " VERSION_BUILD

  !searchreplace VERSION_MAJOR ${VERSION_MAJOR} " " ""
  !searchreplace VERSION_MINOR ${VERSION_MINOR} " " ""
  !searchreplace VERSION_REVISION ${VERSION_REVISION} " " ""
  !searchreplace VERSION_BETA  "${VERSION_BETA}"   " " ""
  !searchreplace VERSION_BUILD "${VERSION_BUILD}" " " ""
  
  !if "${VERSION_BUILD}" == "0"
    !define VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_REVISION}"
  !else
    !define VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_REVISION}${VERSION_BETA}${VERSION_BUILD}"
  !endif
  
  !echo "VERSION = ${VERSION}"
  !define AUTHOR "Rainer Schuetze"
  !define APPNAME "VisualD"
  !define LONG_APPNAME "Visual D"
  !define VERYLONG_APPNAME "Visual D - Visual Studio Integration of the D Programming Language"

  !define DLLNAME "visuald.dll"
  !define CONFIG  "Release"

  ;Name and file
  Name "${LONG_APPNAME}"
  Caption "${LONG_APPNAME} ${VERSION} Setup"
  OutFile "..\..\downloads\${APPNAME}-v${VERSION}.exe"

  !define UNINSTALL_REGISTRY_ROOT HKLM
  !define UNINSTALL_REGISTRY_KEY  Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}

  !define MEMENTO_REGISTRY_ROOT   ${UNINSTALL_REGISTRY_ROOT}
  !define MEMENTO_REGISTRY_KEY    ${UNINSTALL_REGISTRY_KEY}
  
  !define VS_REGISTRY_ROOT        HKLM
!ifdef VS_NET
  !define VS_NET_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\7.1
!endif
  !define VS2005_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\8.0
  !define VS2008_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\9.0
  !define VS2010_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\10.0
  !define VS2012_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\11.0
  !define VS2013_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\12.0
  !define VS2015_REGISTRY_KEY     SOFTWARE\Microsoft\VisualStudio\14.0
!ifdef EXPRESS
  !define VCEXP2008_REGISTRY_KEY  SOFTWARE\Microsoft\VCExpress\9.0
  !define VCEXP2010_REGISTRY_KEY  SOFTWARE\Microsoft\VCExpress\10.0
!endif
  !define VDSETTINGS_KEY          "\ToolsOptionsPages\Projects\Visual D Settings"
  
  !define EXTENSION_DIR_ROOT      "\Extensions\${AUTHOR}"
  !define EXTENSION_DIR           "\Extensions\${AUTHOR}\${APPNAME}\${VERSION_MAJOR}.${VERSION_MINOR}"
  
  !define WIN32_EXCEPTION_KEY     AD7Metrics\Exception\{3B476D35-A401-11D2-AAD4-00C04F990171}
  
!ifdef MAGO
  !define MAGO_CLSID              {97348AC0-2B6B-4B99-A245-4C7E2C09D403}
  !define MAGO_ENGINE_KEY         AD7Metrics\Engine\${MAGO_CLSID}
  !define MAGO_EXCEPTION_KEY      AD7Metrics\Exception\${MAGO_CLSID}
  !define MAGO_ABOUT              "A debug engine dedicated to debugging applications written in the D programming language. See the project website at http://www.dsource.org/projects/mago_debugger for more information. Copyright (c) 2010-2014 Aldo J. Nunez"
  !define MAGO_SOURCE             ..\..\..\mago

  !searchparse /file ${MAGO_SOURCE}/include/magoversion.h "#define MAGO_VERSION_MAJOR " MAGO_VERSION_MAJOR
  !searchparse /file ${MAGO_SOURCE}/include/magoversion.h "#define MAGO_VERSION_MINOR " MAGO_VERSION_MINOR
  !searchparse /file ${MAGO_SOURCE}/include/magoversion.h "#define MAGO_VERSION_BUILD " MAGO_VERSION_BUILD

  !searchreplace MAGO_VERSION_MAJOR ${MAGO_VERSION_MAJOR} " " ""
  !searchreplace MAGO_VERSION_MINOR ${MAGO_VERSION_MINOR} " " ""
  !searchreplace MAGO_VERSION_BUILD ${MAGO_VERSION_BUILD} " " ""

  !define MAGO_VERSION "${MAGO_VERSION_MAJOR}.${MAGO_VERSION_MINOR}.${MAGO_VERSION_BUILD}"
  !echo "MAGO_VERSION = ${MAGO_VERSION}"
!endif

  ;Default installation folder
  InstallDir "$PROGRAMFILES\${APPNAME}"

  ;Get installation folder from registry if available
  InstallDirRegKey HKCU "Software\${APPNAME}" ""

  ;Request admin privileges for Windows Vista
  RequestExecutionLevel admin

  ReserveFile "dmdinstall.ini"

;--------------------------------
; register win32 macro
!macro RegisterWin32Exception Root Exception
  WriteRegDWORD ${VS_REGISTRY_ROOT} "${Root}\${WIN32_EXCEPTION_KEY}\${Exception}" "Code" 0xE0440001
  WriteRegDWORD ${VS_REGISTRY_ROOT} "${Root}\${WIN32_EXCEPTION_KEY}\${Exception}" "State" 3
!macroend
!define RegisterWin32Exception "!insertmacro RegisterWin32Exception"

; register macro
!macro RegisterException Root Exception
  WriteRegDWORD ${VS_REGISTRY_ROOT} "${Root}\${MAGO_EXCEPTION_KEY}\${Exception}" "Code" 0
  WriteRegDWORD ${VS_REGISTRY_ROOT} "${Root}\${MAGO_EXCEPTION_KEY}\${Exception}" "State" 3
!macroend
!define RegisterException "!insertmacro RegisterException"

;--------------------------------
;installation time variables
  Var DMDInstallDir
  Var DInstallDir

;--------------------------------
;Interface Settings

  !define MUI_ABORTWARNING

;--------------------------------
;Pages

  !define MUI_TEXT_WELCOME_INFO_TITLE "Welcome to the ${LONG_APPNAME} ${VERSION} Setup Wizard"
  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_LICENSE "license"
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MUI_PAGE_DIRECTORY

  Page custom DMDInstallPage ValidateDMDInstallPage
  
  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro MUI_PAGE_FINISH

  !insertmacro MUI_UNPAGE_WELCOME
  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES
  !insertmacro MUI_UNPAGE_FINISH

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Section

Section -openlogfile
 CreateDirectory "$INSTDIR"
 IfFileExists "$INSTDIR\${UninstLog}" +3
  FileOpen $UninstLog "$INSTDIR\${UninstLog}" w
 Goto +4
  SetFileAttributes "$INSTDIR\${UninstLog}" NORMAL
  FileOpen $UninstLog "$INSTDIR\${UninstLog}" a
  FileSeek $UninstLog 0 END
SectionEnd

Section "Visual Studio package" SecPackage

  SectionIn RO
  ${SetOutPath} "$INSTDIR"
  
  ${File} ..\bin\${CONFIG}\ ${DLLNAME}
  ${File} ..\bin\${CONFIG}\ vdserver.tlb
  ${File} ..\bin\${CONFIG}\ pipedmd.exe
  ${File} ..\bin\${CONFIG}\ filemonitor.dll
  ${File} ..\bin\${CONFIG}\ dcxxfilt.exe
  ${File} ..\ README.md
  ${File} ..\ LICENSE_1_0.txt
  ${File} ..\ CHANGES

!ifdef VDSERVER
  ${File} ..\bin\${CONFIG}\ vdserver.exe
!endif

  !ifdef VDEXTENSIONS
  ${File} ..\bin\${CONFIG}\vdextensions\ vdextensions.dll
  !endif

!ifdef DPARSER
  ${SetOutPath} "$INSTDIR\DParser"
  ${File} ..\bin\Release\DParserCOMServer\ DParserCOMServer.exe
  ${File} ..\bin\Release\DParserCOMServer\ D_Parser.dll
!endif


  ${SetOutPath} "$INSTDIR\Templates"
  ${SetOutPath} "$INSTDIR\Templates\Items"
  ${File} ..\visuald\Templates\Items\ empty.d
  ${File} ..\visuald\Templates\Items\ hello.d
  ${File} ..\visuald\Templates\Items\ items.vsdir
  ${SetOutPath} "$INSTDIR\Templates\Wizards"
  ${File} ..\visuald\Templates\Wizards\ package.vsz

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems"
  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\ConsoleApp"
  ${File} ..\visuald\Templates\ProjectItems\ConsoleApp\ main.d
  ${File} ..\visuald\Templates\ProjectItems\ConsoleApp\ ConsoleApp.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\ConsoleApp\ ConsoleApp.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\ConsoleDMDGDC"
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDGDC\ main.d
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDGDC\ ConsoleApp.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDGDC\ ConsoleApp.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\ConsoleDMDLDC"
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDLDC\ main.d
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDLDC\ ConsoleApp.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\ConsoleDMDLDC\ ConsoleApp.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\WindowsApp"
  ${File} ..\visuald\Templates\ProjectItems\WindowsApp\ winmain.d
  ${File} ..\visuald\Templates\ProjectItems\WindowsApp\ WindowsApp.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\WindowsApp\ WindowsApp.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\DynamicLib"
  ${File} ..\visuald\Templates\ProjectItems\DynamicLib\ dllmain.d
  ${File} ..\visuald\Templates\ProjectItems\DynamicLib\ dll.def
  ${File} ..\visuald\Templates\ProjectItems\DynamicLib\ DynamicLib.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\DynamicLib\ DynamicLib.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\ProjectItems\StaticLib"
  ${File} ..\visuald\Templates\ProjectItems\StaticLib\ lib.d
  ${File} ..\visuald\Templates\ProjectItems\StaticLib\ StaticLib.vstemplate
  ${File} ..\visuald\Templates\ProjectItems\StaticLib\ StaticLib.visualdproj

  ${SetOutPath} "$INSTDIR\Templates\Projects"
  ${File} ..\visuald\Templates\Projects\ DTemplates.vsdir

  ${SetOutPath} "$INSTDIR\Templates\CodeSnippets"
  ${File} ..\visuald\Templates\CodeSnippets\ SnippetsIndex.xml
  
  ${SetOutPath} "$INSTDIR\Templates\CodeSnippets\Snippets"
  ${File} ..\visuald\Templates\CodeSnippets\Snippets\ *.snippet

  Call RegisterIVDServer
!ifdef VDSERVER
  Call RegisterVDServer
!endif

!ifdef DPARSER
  Call RegisterDParser
!endif

  ;Store installation folder
  WriteRegStr HKCU "Software\${APPNAME}" "" $INSTDIR

  ;Create uninstaller
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "DisplayName" "${VERYLONG_APPNAME}"
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "DisplayIcon" "$INSTDIR\${DLLNAME}"
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "Publisher" "${AUTHOR}"
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "Comments" "${VERYLONG_APPNAME}"
  WriteRegStr ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  
  WriteUninstaller "$INSTDIR\Uninstall.exe"
 
SectionEnd

!ifdef VS_NET
;--------------------------------
${MementoSection} "Register with VS.NET" SecVS_NET

  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS_NET_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS_NET_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS_NET_REGISTRY_KEY} "Win32 Exceptions\D Exception"
  
${MementoSectionEnd}
!endif

;--------------------------------
${MementoSection} "Register with VS 2005" SecVS2005

  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2005_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2005_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS2005_REGISTRY_KEY} "Win32 Exceptions\D Exception"
  
${MementoSectionEnd}

;--------------------------------
${MementoSection} "Register with VS 2008" SecVS2008

  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2008_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2008_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir 
  ${RegisterWin32Exception} ${VS2008_REGISTRY_KEY} "Win32 Exceptions\D Exception"

${MementoSectionEnd}

;--------------------------------
${MementoSection} "Register with VS 2010" SecVS2010

  ;ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2010_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2010_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS2010_REGISTRY_KEY} "Win32 Exceptions\D Exception"

  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2010_REGISTRY_KEY}" InstallDir
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" WritePackageDef ${VS2010_REGISTRY_KEY} $1${EXTENSION_DIR}\visuald.pkgdef'

  ${SetOutPath} "$1${EXTENSION_DIR}"
  ${File} ..\nsis\Extensions\ extension.vsixmanifest
  ${File} ..\nsis\Extensions\ vdlogo.ico
  
  !ifdef VDEXTENSIONS
    GetFullPathName /SHORT $0 $INSTDIR
    !insertmacro ReplaceInFile "$1${EXTENSION_DIR}\extension.vsixmanifest" "VDINSTALLPATH" "$0" NoBackup
  !endif

${MementoSectionEnd}

;--------------------------------
${MementoSection} "Register with VS 2012" SecVS2012

  ;ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2012_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2012_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS2012_REGISTRY_KEY} "Win32 Exceptions\D Exception"

  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2012_REGISTRY_KEY}" InstallDir
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" WritePackageDef ${VS2012_REGISTRY_KEY} $1${EXTENSION_DIR}\visuald.pkgdef'

  ${SetOutPath} "$1${EXTENSION_DIR}"
  ${File} ..\nsis\Extensions\ extension.vsixmanifest
  ${File} ..\nsis\Extensions\ vdlogo.ico
  
  !ifdef VDEXTENSIONS
    GetFullPathName /SHORT $0 $INSTDIR
    !insertmacro ReplaceInFile "$1${EXTENSION_DIR}\extension.vsixmanifest" "VDINSTALLPATH" "$0" NoBackup
  !endif

${MementoSectionEnd}

;--------------------------------
${MementoSection} "Register with VS 2013" SecVS2013

  ;ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2013_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2013_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS2013_REGISTRY_KEY} "Win32 Exceptions\D Exception"

  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2013_REGISTRY_KEY}" InstallDir
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" WritePackageDef ${VS2013_REGISTRY_KEY} $1${EXTENSION_DIR}\visuald.pkgdef'

  ${SetOutPath} "$1${EXTENSION_DIR}"
  ${File} ..\nsis\Extensions\ extension.vsixmanifest
  ${File} ..\nsis\Extensions\ vdlogo.ico

  !ifdef VDEXTENSIONS
    GetFullPathName /SHORT $0 $INSTDIR
    !insertmacro ReplaceInFile "$1${EXTENSION_DIR}\extension.vsixmanifest" "VDINSTALLPATH" "$0" NoBackup
  !endif

${MementoSectionEnd}

;--------------------------------
${MementoSection} "Register with VS 2015" SecVS2015

  ;ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VS2015_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VS2015_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  ${RegisterWin32Exception} ${VS2015_REGISTRY_KEY} "Win32 Exceptions\D Exception"

  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2015_REGISTRY_KEY}" InstallDir
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" WritePackageDef ${VS2015_REGISTRY_KEY} $1${EXTENSION_DIR}\visuald.pkgdef'

  ${SetOutPath} "$1${EXTENSION_DIR}"
  ${File} ..\nsis\Extensions\ extension.vsixmanifest
  ${File} ..\nsis\Extensions\ vdlogo.ico

  !ifdef VDEXTENSIONS
    GetFullPathName /SHORT $0 $INSTDIR
    !insertmacro ReplaceInFile "$1${EXTENSION_DIR}\extension.vsixmanifest" "VDINSTALLPATH" "$0" NoBackup
  !endif

${MementoSectionEnd}

!ifdef EXPRESS
;--------------------------------
${MementoUnselectedSection} "Register with VC-Express 2008" SecVCExpress2008

  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VCEXP2008_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VCEXP2008_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  
${MementoSectionEnd}

;--------------------------------
${MementoUnselectedSection} "Register with VC-Express 2010" SecVCExpress2010

  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLRegister ${VCEXP2010_REGISTRY_KEY}'
  WriteRegStr ${VS_REGISTRY_ROOT} "${VCEXP2010_REGISTRY_KEY}${VDSETTINGS_KEY}" "DMDInstallDir" $DMDInstallDir
  
${MementoSectionEnd}
!endif

!ifdef CV2PDB
;--------------------------------
${MementoSection} "cv2pdb" SecCv2pdb

  ${SetOutPath} "$INSTDIR\cv2pdb"
  ${File} ..\..\..\cv2pdb\trunk\ autoexp.expand
  ${File} ..\..\..\cv2pdb\trunk\ autoexp.visualizer
  ${File} ..\..\..\cv2pdb\trunk\bin\Release\ cv2pdb.exe
  ${File} ..\..\..\cv2pdb\trunk\bin\Release\ dviewhelper.dll
  ${File} ..\..\..\cv2pdb\trunk\bin\Release\ dumplines.exe
  ${File} ..\..\..\cv2pdb\trunk\ README
  ${File} ..\..\..\cv2pdb\trunk\ LICENSE
  ${File} ..\..\..\cv2pdb\trunk\ CHANGES
  ${File} ..\..\..\cv2pdb\trunk\ VERSION
  ${File} ..\..\..\cv2pdb\trunk\ FEATURES
  ${File} ..\..\..\cv2pdb\trunk\ INSTALL
  ${File} ..\..\..\cv2pdb\trunk\ TODO

  GetFullPathName /SHORT $0 $INSTDIR
  !insertmacro ReplaceInFile "$INSTDIR\cv2pdb\autoexp.expand" "dviewhelper" "$0\cv2pdb\DViewHelper" NoBackup

!ifdef VS_NET
  Push ${SecVS_NET}
  Push ${VS_NET_REGISTRY_KEY}
  Call PatchAutoExp
!endif
  
  Push ${SecVS2005}
  Push ${VS2005_REGISTRY_KEY}
  Call PatchAutoExp
  
  Push ${SecVS2008}
  Push ${VS2008_REGISTRY_KEY}
  Call PatchAutoExp
  
  Push ${SecVS2010}
  Push ${VS2010_REGISTRY_KEY}
  Call PatchAutoExp
  
  Push ${SecVS2012}
  Push ${VS2012_REGISTRY_KEY}
  Call PatchAutoExp
  
  Push ${SecVS2013}
  Push ${VS2013_REGISTRY_KEY}
  Call PatchAutoExp
  
  Push ${SecVS2015}
  Push ${VS2015_REGISTRY_KEY}
  Call PatchAutoExp
  
${MementoSectionEnd}
!endif

!ifdef MAGO
;--------------------------------
${MementoSection} "mago" SecMago

  ${SetOutPath} "$INSTDIR\Mago"
  ${File} ${MAGO_SOURCE}\bin\Win32\Release\ MagoNatDE.dll
;;  ${File} ${MAGO_SOURCE}\bin\Win32\Release\ MagoNatEE.dll
  ${File} ${MAGO_SOURCE}\bin\Win32\Release\ udis86.dll
;;  ${File} ${MAGO_SOURCE}\bin\Win32\Release\ CVSTI.dll
  ${File} ${MAGO_SOURCE}\bin\x64\Release\ MagoRemote.exe
  ${File} ${MAGO_SOURCE}\ LICENSE.TXT
  ${File} ${MAGO_SOURCE}\ NOTICE.TXT

  ExecWait 'regsvr32 /s "$INSTDIR\Mago\MagoNatDE.dll"'

!ifdef VS_NET
  Push ${SecVS_NET}
  Push ${VS_NET_REGISTRY_KEY}
  Call RegisterMago
!endif
  
  Push ${SecVS2005}
  Push ${VS2005_REGISTRY_KEY}
  Call RegisterMago
  
  Push ${SecVS2008}
  Push ${VS2008_REGISTRY_KEY}
  Call RegisterMago
  
  Push ${SecVS2010}
  Push ${VS2010_REGISTRY_KEY}
  Call RegisterMago
  
  Push ${SecVS2012}
  Push ${VS2012_REGISTRY_KEY}
  Call RegisterMago
  
  Push ${SecVS2013}
  Push ${VS2013_REGISTRY_KEY}
  Call RegisterMago
  
  Push ${SecVS2015}
  Push ${VS2015_REGISTRY_KEY}
  Call RegisterMago
  
  WriteRegStr HKLM "SOFTWARE\Wow6432Node\MagoDebugger" "Remote_x64" "$INSTDIR\Mago\MagoRemote.exe"

${MementoSectionEnd}
!endif

${MementoSectionDone}

Section -closelogfile
 FileClose $UninstLog
 SetFileAttributes "$INSTDIR\${UninstLog}" READONLY|SYSTEM|HIDDEN
SectionEnd

 ;--------------------------------
;Descriptions

  ;Language strings
  LangString DESC_SecPackage ${LANG_ENGLISH} "The package containing the language service."
!ifdef VS_NET
  LangString DESC_SecVS_NET ${LANG_ENGLISH} "Register for usage in Visual Studio .NET"
!endif
  LangString DESC_SecVS2005 ${LANG_ENGLISH} "Register for usage in Visual Studio 2005."
  LangString DESC_SecVS2008 ${LANG_ENGLISH} "Register for usage in Visual Studio 2008."
  LangString DESC_SecVS2010 ${LANG_ENGLISH} "Register for usage in Visual Studio 2010."
  LangString DESC_SecVS2012 ${LANG_ENGLISH} "Register for usage in Visual Studio 2012."
  LangString DESC_SecVS2013 ${LANG_ENGLISH} "Register for usage in Visual Studio 2013."
  LangString DESC_SecVS2015 ${LANG_ENGLISH} "Register for usage in Visual Studio 2015."
!ifdef EXPRESS
  LangString DESC_SecVCExpress2008 ${LANG_ENGLISH} "Register for usage in Visual C++ Express 2008 (experimental and unusable)."
  LangString DESC_SecVCExpress2010 ${LANG_ENGLISH} "Register for usage in Visual C++ Express 2010 (experimental and unusable)."
!endif
!ifdef CV2PDB
  LangString DESC_SecCv2pdb ${LANG_ENGLISH} "cv2pdb is necessary to debug Win32 executables in Visual Studio."
  LangString DESC_SecCv2pdb2 ${LANG_ENGLISH} "$\r$\nYou might not want to install it, if you have already installed it elsewhere."
!endif  
!ifdef MAGO
  LangString DESC_SecMago ${LANG_ENGLISH} "Mago is a debug engine especially designed for the D-Language."
  LangString DESC_SecMago2 ${LANG_ENGLISH} "$\r$\nMago is written by Aldo Nunez. Distributed under the Apache License Version 2.0. See www.dsource.org/ projects/mago_debugger"
!endif  

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecPackage} $(DESC_SecPackage)
!ifdef VS_NET
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS_NET} $(DESC_SecVS_NET)
!endif
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2005} $(DESC_SecVS2005)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2008} $(DESC_SecVS2008)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2010} $(DESC_SecVS2010)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2012} $(DESC_SecVS2012)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2013} $(DESC_SecVS2013)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVS2015} $(DESC_SecVS2015)
!ifdef EXPRESS
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVCExpress2008} $(DESC_SecVCExpress2008)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecVCExpress2008} $(DESC_SecVCExpress2010)
!endif
!ifdef CV2PDB
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCv2pdb} $(DESC_SecCv2pdb)$(DESC_SecCv2pdb2)
!endif
!ifdef MAGO
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMago} $(DESC_SecMago)$(DESC_SecMago2)
!endif
  !insertmacro MUI_FUNCTION_DESCRIPTION_END


;--------------------------------
;Uninstaller Section

Section "Uninstall"

!ifdef VS_NET
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS_NET_REGISTRY_KEY}'
!endif
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2005_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2008_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2010_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2012_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2013_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VS2015_REGISTRY_KEY}'
!ifdef EXPRESS
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VCEXP2008_REGISTRY_KEY}'
  ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" RunDLLUnregister ${VCEXP2010_REGISTRY_KEY}'
!endif

  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2015_REGISTRY_KEY}" InstallDir
  IfErrors NoVS2015pkgdef
    RMDir /r '$1${EXTENSION_DIR}'
    RMDir '$1${EXTENSION_DIR_ROOT}\${APPNAME}'
    RMDir '$1${EXTENSION_DIR_ROOT}'
  NoVS2015pkgdef:
  
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2013_REGISTRY_KEY}" InstallDir
  IfErrors NoVS2013pkgdef
    RMDir /r '$1${EXTENSION_DIR}'
    RMDir '$1${EXTENSION_DIR_ROOT}\${APPNAME}'
    RMDir '$1${EXTENSION_DIR_ROOT}'
  NoVS2013pkgdef:
  
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2012_REGISTRY_KEY}" InstallDir
  IfErrors NoVS2012pkgdef
    RMDir /r '$1${EXTENSION_DIR}'
    RMDir '$1${EXTENSION_DIR_ROOT}\${APPNAME}'
    RMDir '$1${EXTENSION_DIR_ROOT}'
  NoVS2012pkgdef:
  
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2010_REGISTRY_KEY}" InstallDir
  IfErrors NoVS2010pkgdef
    RMDir /r '$1${EXTENSION_DIR}'
    RMDir '$1${EXTENSION_DIR_ROOT}\${APPNAME}'
    RMDir '$1${EXTENSION_DIR_ROOT}'
  NoVS2010pkgdef:

!ifdef CV2PDB
!ifdef VS_NET
  Push ${VS_NET_REGISTRY_KEY}
  Call un.PatchAutoExp
!endif
  
  Push ${VS2005_REGISTRY_KEY}
  Call un.PatchAutoExp
  
  Push ${VS2008_REGISTRY_KEY}
  Call un.PatchAutoExp
  
  Push ${VS2010_REGISTRY_KEY}
  Call un.PatchAutoExp

  Push ${VS2012_REGISTRY_KEY}
  Call un.PatchAutoExp

  Push ${VS2013_REGISTRY_KEY}
  Call un.PatchAutoExp

  Push ${VS2015_REGISTRY_KEY}
  Call un.PatchAutoExp
!endif

!ifdef VS_NET
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS_NET_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
!endif
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2005_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2008_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2010_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2012_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2013_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2015_REGISTRY_KEY}\${WIN32_EXCEPTION_KEY}\Win32 Exceptions\D Exception"

!ifdef MAGO
  ExecWait 'regsvr32 /u /s "$INSTDIR\Mago\MagoNatDE.dll"'
  
!ifdef VS_NET
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS_NET_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
!endif
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2005_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2008_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2010_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2012_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2013_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2015_REGISTRY_KEY}\${MAGO_ENGINE_KEY}"

!ifdef VS_NET
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS_NET_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
!endif
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2005_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2008_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2010_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2012_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2013_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2015_REGISTRY_KEY}\${MAGO_EXCEPTION_KEY}"

!ifdef VS_NET
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS_NET_REGISTRY_KEY}\InstalledProducts\Mago"
!endif
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2005_REGISTRY_KEY}\InstalledProducts\Mago"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2008_REGISTRY_KEY}\InstalledProducts\Mago"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2010_REGISTRY_KEY}\InstalledProducts\Mago"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2012_REGISTRY_KEY}\InstalledProducts\Mago"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2013_REGISTRY_KEY}\InstalledProducts\Mago"
  DeleteRegKey ${VS_REGISTRY_ROOT}   "${VS2015_REGISTRY_KEY}\InstalledProducts\Mago"
!endif
  
  Call un.RegisterIVDServer
  Call un.RegisterVDServer
  Call un.RegisterDParser

  Call un.installedFiles
  ;ADD YOUR OWN FILES HERE...
  ;Delete "$INSTDIR\${DLLNAME}"

  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  DeleteRegKey ${UNINSTALL_REGISTRY_ROOT} "${UNINSTALL_REGISTRY_KEY}"
  DeleteRegKey HKLM "SOFTWARE\${APPNAME}"
  DeleteRegKey HKCU "Software\${APPNAME}"
  ; /ifempty 

SectionEnd

;--------------------------------
Function .onInstSuccess

  ${MementoSectionSave}

FunctionEnd

;--------------------------------
Function .onInit

  ${MementoSectionRestore}

!ifdef VS_NET
  ; detect VS.NET
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS_NET_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS_NET
    SectionSetFlags ${SecVS_NET} ${SF_RO}
  Installed_VS_NET:
!endif
  
  ; detect VS2005
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2005_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2005
    SectionSetFlags ${SecVS2005} ${SF_RO}
  Installed_VS2005:
  
  ; detect VS2008
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2008_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2008
    SectionSetFlags ${SecVS2008} ${SF_RO}
  Installed_VS2008:

  ; detect VS2010
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2010_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2010
    SectionSetFlags ${SecVS2010} ${SF_RO}
  Installed_VS2010:

  ; detect VS2012
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2012_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2012
    SectionSetFlags ${SecVS2012} ${SF_RO}
  Installed_VS2012:

  ; detect VS2013
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2013_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2013
    SectionSetFlags ${SecVS2013} ${SF_RO}
  Installed_VS2013:

  ; detect VS2015
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VS2015_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VS2015
    SectionSetFlags ${SecVS2015} ${SF_RO}
  Installed_VS2015:

!ifdef EXPRESS
  ; detect VCExpress 2008
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VCEXP2008_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VCExpress2008
    SectionSetFlags ${SecVcExpress2008} ${SF_RO}
  Installed_VCExpress2008:

  ; detect VCExpress 2010
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "${VCEXP2010_REGISTRY_KEY}" InstallDir
  IfErrors 0 Installed_VCExpress2010
    SectionSetFlags ${SecVcExpress2010} ${SF_RO}
  Installed_VCExpress2010:
!endif

  !insertmacro INSTALLOPTIONS_EXTRACT "dmdinstall.ini"
  
FunctionEnd

;--------------------------------
Function DMDInstallPage

  !insertmacro MUI_HEADER_TEXT "DMD Installation Folder" "Specify the directory where DMD is installed"

  ReadRegStr $DMDInstallDir HKLM "Software\${APPNAME}" "DMDInstallDir" 
  IfErrors DMDInstallDirEmpty
  StrCmp "$DMDInstallDir" "" DMDInstallDirEmpty HasDMDInstallDir
  DMDInstallDirEmpty:
    ReadRegStr $DInstallDir HKLM "SOFTWARE\DMD" "InstallationFolder" 
    IfErrors 0 HasDInstallationFolder
    ReadRegStr $DInstallDir HKLM "SOFTWARE\D" "Install_Dir" 
    IfErrors HasDmdInstallDir
  HasDInstallationFolder:
    StrCpy $DmdInstallDir $DInstallDir\dmd2
  HasDMDInstallDir:
  
  WriteINIStr "$PLUGINSDIR\dmdinstall.ini" "Field 1" "State" $DMDInstallDir
  !insertmacro INSTALLOPTIONS_DISPLAY "dmdinstall.ini"
  
FunctionEnd

Function ValidateDMDInstallPage
  ReadINIStr $DMDInstallDir "$PLUGINSDIR\dmdinstall.ini" "Field 1" "State"
  WriteRegStr HKLM "Software\${APPNAME}" "DMDInstallDir" $DMDInstallDir
FunctionEnd

!define AutoExpPath ..\Packages\Debugger\autoexp.dat

Function PatchAutoExp
  Exch $1
  Exch
  Exch $0
  Push $2
  
  SectionGetFlags $0 $2
  IntOp $2 $2 & ${SF_SELECTED}
  IntCmp $2 ${SF_SELECTED} enabled NoInstall

enabled:
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "$1" InstallDir
  IfErrors NoInstall

  IfFileExists "$1${AutoExpPath}" +1 NoInstall
    
    # make backup
    CopyFiles /SILENT "$1${AutoExpPath}" "$1${AutoExpPath}.bak"
    
    !insertmacro RemoveFromFile "$1${AutoExpPath}" ";; added to [AutoExpand] for cv2pdb" ";; eo added for cv2pdb" NoBackup
    IfErrors SkipAutoExp
      !insertmacro InsertToFile "$1${AutoExpPath}" "[AutoExpand]" "$INSTDIR\cv2pdb\autoexp.expand" NoBackup
    SkipAutoExp:

    !insertmacro RemoveFromFile "$1${AutoExpPath}" ";; added to [Visualizer] for cv2pdb" ";; eo added for cv2pdb" NoBackup
    IfErrors SkipVisualizer
      !insertmacro InsertToFile "$1${AutoExpPath}" "[Visualizer]" "$INSTDIR\cv2pdb\autoexp.visualizer" NoBackup
    SkipVisualizer:
    
    ;;; ExecWait 'rundll32 "$INSTDIR\${DLLNAME}" VerifyMSObj $1'
    
  NoInstall:

  Pop $2
  Pop $0
  Pop $1
FunctionEnd

Function un.PatchAutoExp
  Exch $1
  
  ClearErrors
  ReadRegStr $1 ${VS_REGISTRY_ROOT} "$1" InstallDir
  IfErrors NoInstallDir

    IfFileExists "$1${AutoExpPath}" +1 NoInstallDir
    # make backup
    CopyFiles /SILENT "$1${AutoExpPath}" "$1${AutoExpPath}.bak"
    
    !insertmacro un.RemoveFromFile "$1${AutoExpPath}" ";; added to [AutoExpand] for cv2pdb" ";; eo added for cv2pdb" NoBackup
    !insertmacro un.RemoveFromFile "$1${AutoExpPath}" ";; added to [Visualizer] for cv2pdb" ";; eo added for cv2pdb" NoBackup
    
  NoInstallDir:

  Pop $1
FunctionEnd

;---------------------------------------
Function RegisterMago
  Exch $1
  Exch
  Exch $0
  Push $2
  
  SectionGetFlags $0 $2
  IntOp $2 $2 & ${SF_SELECTED}
  IntCmp $2 ${SF_SELECTED} enabled NoInstall

  # $1 contains registry root
enabled:
  ClearErrors
  
  WriteRegStr ${VS_REGISTRY_ROOT} "$1\InstalledProducts\Mago" "" "Mago Native Debug Engine"
  WriteRegStr ${VS_REGISTRY_ROOT} "$1\InstalledProducts\Mago" "PID" "${MAGO_VERSION}"
  WriteRegStr ${VS_REGISTRY_ROOT} "$1\InstalledProducts\Mago" "ProductDetails" "${MAGO_ABOUT}"
  
  WriteRegStr ${VS_REGISTRY_ROOT}   "$1\${MAGO_ENGINE_KEY}" "CLSID" "${MAGO_CLSID}" 
  WriteRegStr ${VS_REGISTRY_ROOT}   "$1\${MAGO_ENGINE_KEY}" "Name"  "Mago Native" 
  WriteRegDWORD ${VS_REGISTRY_ROOT} "$1\${MAGO_ENGINE_KEY}" "ENC" 0
  WriteRegDWORD ${VS_REGISTRY_ROOT} "$1\${MAGO_ENGINE_KEY}" "Disassembly" 1
  WriteRegDWORD ${VS_REGISTRY_ROOT} "$1\${MAGO_ENGINE_KEY}" "Exceptions" 1
  WriteRegDWORD ${VS_REGISTRY_ROOT} "$1\${MAGO_ENGINE_KEY}" "AlwaysLoadLocal" 1

  ${RegisterException} $1 "D Exceptions"
  ${RegisterException} $1 "D Exceptions\core.exception.AssertError"
  ${RegisterException} $1 "D Exceptions\core.exception.FinalizeError"
  ${RegisterException} $1 "D Exceptions\core.exception.HiddenFuncError"
  ${RegisterException} $1 "D Exceptions\core.exception.OutOfMemoryError"
  ${RegisterException} $1 "D Exceptions\core.exception.RangeError"
  ${RegisterException} $1 "D Exceptions\core.exception.SwitchError"
  ${RegisterException} $1 "D Exceptions\core.exception.UnicodeException"
  ${RegisterException} $1 "D Exceptions\core.sync.exception.SyncException"
  ${RegisterException} $1 "D Exceptions\core.thread.FiberException"
  ${RegisterException} $1 "D Exceptions\core.thread.ThreadException"
  ${RegisterException} $1 "D Exceptions\object.Error"
  ${RegisterException} $1 "D Exceptions\object.Exception"
  ${RegisterException} $1 "D Exceptions\std.base64.Base64CharException"
  ${RegisterException} $1 "D Exceptions\std.base64.Base64Exception"
  ${RegisterException} $1 "D Exceptions\std.boxer.UnboxException"
  ${RegisterException} $1 "D Exceptions\std.concurrency.LinkTerminated"
  ${RegisterException} $1 "D Exceptions\std.concurrency.MailboxFull"
  ${RegisterException} $1 "D Exceptions\std.concurrency.MessageMismatch"
  ${RegisterException} $1 "D Exceptions\std.concurrency.OwnerTerminated"
  ${RegisterException} $1 "D Exceptions\std.conv.ConvError"
  ${RegisterException} $1 "D Exceptions\std.conv.ConvOverflowError"
  ${RegisterException} $1 "D Exceptions\std.dateparse.DateParseError"
  ${RegisterException} $1 "D Exceptions\std.demangle.MangleException"
  ${RegisterException} $1 "D Exceptions\std.encoding.EncodingException"
  ${RegisterException} $1 "D Exceptions\std.encoding.UnrecognizedEncodingException"
  ${RegisterException} $1 "D Exceptions\std.exception.ErrnoException"
  ${RegisterException} $1 "D Exceptions\std.file.FileException"
  ${RegisterException} $1 "D Exceptions\std.format.FormatError"
  ${RegisterException} $1 "D Exceptions\std.json.JSONException"
  ${RegisterException} $1 "D Exceptions\std.loader.ExeModuleException"
  ${RegisterException} $1 "D Exceptions\std.math.NotImplemented"
  ${RegisterException} $1 "D Exceptions\std.regexp.RegExpException"
  ${RegisterException} $1 "D Exceptions\std.socket.AddressException"
  ${RegisterException} $1 "D Exceptions\std.socket.HostException"
  ${RegisterException} $1 "D Exceptions\std.socket.SocketAcceptException"
  ${RegisterException} $1 "D Exceptions\std.socket.SocketException"
  ${RegisterException} $1 "D Exceptions\std.stdio.StdioException"
  ${RegisterException} $1 "D Exceptions\std.stream.OpenException"
  ${RegisterException} $1 "D Exceptions\std.stream.ReadException"
  ${RegisterException} $1 "D Exceptions\std.stream.SeekException"
  ${RegisterException} $1 "D Exceptions\std.stream.StreamException"
  ${RegisterException} $1 "D Exceptions\std.stream.StreamFileException"
  ${RegisterException} $1 "D Exceptions\std.stream.WriteException"
  ${RegisterException} $1 "D Exceptions\std.typecons.NotImplementedError"
  ${RegisterException} $1 "D Exceptions\std.uri.URIerror"
  ${RegisterException} $1 "D Exceptions\std.utf.UtfError"
  ${RegisterException} $1 "D Exceptions\std.utf.UtfException"
  ${RegisterException} $1 "D Exceptions\std.variant.VariantException"
  ${RegisterException} $1 "D Exceptions\std.windows.registry.RegistryException"
  ${RegisterException} $1 "D Exceptions\std.windows.registry.Win32Exception"
  ${RegisterException} $1 "D Exceptions\std.xml.CDataException"
  ${RegisterException} $1 "D Exceptions\std.xml.CheckException"
  ${RegisterException} $1 "D Exceptions\std.xml.CommentException"
  ${RegisterException} $1 "D Exceptions\std.xml.DecodeException"
  ${RegisterException} $1 "D Exceptions\std.xml.InvalidTypeException"
  ${RegisterException} $1 "D Exceptions\std.xml.PIException"
  ${RegisterException} $1 "D Exceptions\std.xml.TagException"
  ${RegisterException} $1 "D Exceptions\std.xml.TextException"
  ${RegisterException} $1 "D Exceptions\std.xml.XIException"
  ${RegisterException} $1 "D Exceptions\std.xml.XMLException"
  ${RegisterException} $1 "D Exceptions\std.zip.ZipException"
  ${RegisterException} $1 "D Exceptions\std.zlib.ZlibException"
    
NoInstall:

  Pop $2
  Pop $0
  Pop $1
FunctionEnd

;---------------------------------------
!define VDSERVER_REG_ROOT                   HKCR
!define VDSERVER_FACTORY_NAME               visuald.vdserver.factory
!define VDSERVER_FACTORY_CLSID              {002a2de9-8bb6-484d-9902-7e4ad4084715}
!define VDSERVER_TYPELIB_CLSID              {002a2de9-8bb6-484d-9903-7e4ad4084715}
!define VDSERVER_INTERFACE_NAME             IVDServer
!define VDSERVER_INTERFACE_CLSID            {002a2de9-8bb6-484d-9901-7e4ad4084715}

Function RegisterIVDServer

  WriteRegStr ${VDSERVER_REG_ROOT} "TypeLib\${VDSERVER_TYPELIB_CLSID}\1.0\0\win32" "" $INSTDIR\vdserver.tlb
  WriteRegStr ${VDSERVER_REG_ROOT} "Interface\${VDSERVER_INTERFACE_CLSID}"         "" ${VDSERVER_INTERFACE_NAME}
  WriteRegStr ${VDSERVER_REG_ROOT} "Interface\${VDSERVER_INTERFACE_CLSID}\ProxyStubClsid32" "" {00020424-0000-0000-C000-000000000046}
  WriteRegStr ${VDSERVER_REG_ROOT} "Interface\${VDSERVER_INTERFACE_CLSID}\TypeLib" "" ${VDSERVER_TYPELIB_CLSID}

FunctionEnd

Function un.RegisterIVDServer

  DeleteRegKey ${VDSERVER_REG_ROOT} "TypeLib\${VDSERVER_TYPELIB_CLSID}" 
  DeleteRegKey ${VDSERVER_REG_ROOT} "Interface\${VDSERVER_INTERFACE_CLSID}" 

FunctionEnd

Function RegisterVDServer

  WriteRegStr ${VDSERVER_REG_ROOT} "${VDSERVER_FACTORY_NAME}\CLSID"                "" ${VDSERVER_FACTORY_CLSID}
  WriteRegStr ${VDSERVER_REG_ROOT} "CLSID\${VDSERVER_FACTORY_CLSID}\LocalServer32" "" $INSTDIR\vdserver.exe
  WriteRegStr ${VDSERVER_REG_ROOT} "CLSID\${VDSERVER_FACTORY_CLSID}\TypeLib"       "" ${VDSERVER_TYPELIB_CLSID}

FunctionEnd

Function un.RegisterVDServer

  DeleteRegKey ${VDSERVER_REG_ROOT} "${VDSERVER_FACTORY_NAME}" 
  DeleteRegKey ${VDSERVER_REG_ROOT} "CLSID\${VDSERVER_FACTORY_CLSID}"

FunctionEnd

;---------------------------------------
!define DPARSER_REG_ROOT                   HKCR
!define DPARSER_FACTORY_NAME               DParserCOMServer.VDServerClassFactory
!define DPARSER_FACTORY_CLSID              {002a2de9-8bb6-484d-aa02-7e4ad4084715}
!define DPARSER_VDSERVER_CLSID             {002a2de9-8bb6-484d-aa05-7e4ad4084715}
; typelib and IVDServer interface inherited from vdserver.exe

Function RegisterDParser

;  WriteRegStr ${DPARSER_REG_ROOT} "${DPARSER_FACTORY_NAME}\CLSID"                "" ${DPARSER_FACTORY_CLSID}
;  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_FACTORY_CLSID}\LocalServer32" "" $INSTDIR\DParser\DParserCOMServer.exe
;  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_FACTORY_CLSID}\ProgId"        "" DParserCOMServer.VDServer
;  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_FACTORY_CLSID}\Implemented Categories\{62C8FE65-4EBB-45e7-B440-6E39B2CDBF29}" "" ""

  WriteRegStr ${DPARSER_REG_ROOT} "${DPARSER_FACTORY_NAME}\CLSID"                 "" ${DPARSER_VDSERVER_CLSID}
  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_VDSERVER_CLSID}\LocalServer32" "" $INSTDIR\DParser\DParserCOMServer.exe
  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_VDSERVER_CLSID}\ProgId"        "" DParserCOMServer.VDServer
  WriteRegStr ${DPARSER_REG_ROOT} "CLSID\${DPARSER_VDSERVER_CLSID}\Implemented Categories\{62C8FE65-4EBB-45e7-B440-6E39B2CDBF29}" "" ""

FunctionEnd

Function un.RegisterDParser

  DeleteRegKey ${DPARSER_REG_ROOT} "${DPARSER_FACTORY_NAME}" 
  DeleteRegKey ${DPARSER_REG_ROOT} "CLSID\${DPARSER_FACTORY_CLSID}"

FunctionEnd
