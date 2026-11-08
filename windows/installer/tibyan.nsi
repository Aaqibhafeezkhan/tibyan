; Tibyan Windows installer (NSIS 3, Unicode). Built on Linux with makensis by
; scripts/build-win-remote.sh inside windows/installer/docker-compose.win-nsis.yml.
;
;   makensis -DVERSION=0.8.2 -DBUILD=47 -DSRC_DIR=/work/app -DOUT_FILE=/work/out/x.exe tibyan.nsi
;
; Per-user install (no admin prompt) into %LOCALAPPDATA%\Programs\Tibyan.
; Silent update: Setup.exe /S /RELAUNCH  (closes tibyan.exe, installs, starts it again).
Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma

!ifndef VERSION
  !error "pass -DVERSION=x.y.z"
!endif
!ifndef BUILD
  !define BUILD 0
!endif
!ifndef SRC_DIR
  !error "pass -DSRC_DIR=<unzipped flutter Release dir>"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "Tibyan-Windows-Setup-v${VERSION}.exe"
!endif

!define APP_NAME "Tibyan"
!define APP_EXE "tibyan.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tibyan"
!define APP_KEY "Software\Tibyan"

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "Sections.nsh"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Tibyan"
InstallDirRegKey HKCU "${APP_KEY}" "InstallDir"
RequestExecutionLevel user
BrandingText "Tibyan ${VERSION}"

VIProductVersion "${VERSION}.${BUILD}"
VIAddVersionKey /LANG=1033 "ProductName" "Tibyan"
VIAddVersionKey /LANG=1033 "FileDescription" "Tibyan Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${VERSION}+${BUILD}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "GPL-3.0"

!define MUI_ICON "app_icon.ico"
!define MUI_UNICON "app_icon.ico"
!define MUI_ABORTWARNING
!define MUI_LANGDLL_ALLLANGUAGES
!define MUI_LANGDLL_REGISTRY_ROOT HKCU
!define MUI_LANGDLL_REGISTRY_KEY "${APP_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Arabic"
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_RESERVEFILE_LANGDLL

LangString SecApp ${LANG_ARABIC} "تبيان"
LangString SecApp ${LANG_ENGLISH} "Tibyan"
LangString SecDesktop ${LANG_ARABIC} "اختصار على سطح المكتب"
LangString SecDesktop ${LANG_ENGLISH} "Desktop shortcut"
LangString CloseApp ${LANG_ARABIC} "تبيان يعمل الآن. أغلقه ثم اضغط «موافق»، أو «إلغاء» لإيقاف التثبيت."
LangString CloseApp ${LANG_ENGLISH} "Tibyan is running. Close it and press OK, or Cancel to stop the setup."

Var Relaunch

!macro CloseRunningApp
  ; Ask nicely first (interactive), then force: a silent update must never stop
  ; on a locked tibyan.exe.
  nsExec::Exec 'cmd /c tasklist /FI "IMAGENAME eq ${APP_EXE}" | find /I "${APP_EXE}"'
  Pop $0
  ${If} $0 == 0
    ${IfNot} ${Silent}
      MessageBox MB_OKCANCEL|MB_ICONINFORMATION "$(CloseApp)" IDOK +2
      Abort
    ${EndIf}
    nsExec::Exec 'taskkill /F /T /IM ${APP_EXE}'
    Pop $0
    Sleep 1000
  ${EndIf}
!macroend

Section "!$(SecApp)" SEC_APP
  SectionIn RO
  !insertmacro CloseRunningApp
  SetOutPath "$INSTDIR"
  ; The previous version's files go first, so no stale DLL or asset survives.
  RMDir /r "$INSTDIR\data"
  File /r "${SRC_DIR}/*"
  File "app_icon.ico"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\Tibyan"
  CreateShortcut "$SMPROGRAMS\Tibyan\Tibyan.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\app_icon.ico"
  CreateShortcut "$SMPROGRAMS\Tibyan\Uninstall Tibyan.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "Tibyan"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "Tibyan"
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "https://altibyan.app"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\app_icon.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "$(SecDesktop)" SEC_DESKTOP
  CreateShortcut "$DESKTOP\Tibyan.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\app_icon.ico"
SectionEnd

Function .onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/RELAUNCH" $R1
  ${IfNot} ${Errors}
    StrCpy $Relaunch 1
  ${EndIf}
  ${IfNot} ${Silent}
    !insertmacro MUI_LANGDLL_DISPLAY
  ${EndIf}
  ; Keep the user's earlier choice on updates: no desktop shortcut if they
  ; unticked it last time.
  ReadRegDWORD $0 HKCU "${APP_KEY}" "DesktopShortcut"
  ${If} $0 == "0"
  ${AndIf} ${FileExists} "$INSTDIR\${APP_EXE}"
    !insertmacro UnselectSection ${SEC_DESKTOP}
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  ${If} ${SectionIsSelected} ${SEC_DESKTOP}
    WriteRegDWORD HKCU "${APP_KEY}" "DesktopShortcut" 1
  ${Else}
    WriteRegDWORD HKCU "${APP_KEY}" "DesktopShortcut" 0
    Delete "$DESKTOP\Tibyan.lnk"
  ${EndIf}
  ${If} $Relaunch == 1
    Exec '"$INSTDIR\${APP_EXE}"'
  ${EndIf}
FunctionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section "Uninstall"
  !insertmacro CloseRunningApp
  Delete "$DESKTOP\Tibyan.lnk"
  RMDir /r "$SMPROGRAMS\Tibyan"
  ; App data (downloaded mushaf pages, settings) lives under %APPDATA%, not here,
  ; so it survives an uninstall + reinstall.
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "${APP_KEY}"
SectionEnd
