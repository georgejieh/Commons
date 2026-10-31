; Per-user installer with a Start-menu shortcut and an uninstaller.
; Build: makensis -DVERSION=<version> -DSOURCE=<Commons.exe> -DNOTICES=<notices.txt> -DOUTPUT=<setup.exe> commons.nsi

Unicode true
Name "Commons"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\Commons"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Commons"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Commons"
	SetOutPath "$INSTDIR"
	File "/oname=Commons.exe" "${SOURCE}"
	File "/oname=THIRD-PARTY-NOTICES.txt" "${NOTICES}"
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	CreateShortCut "$SMPROGRAMS\Commons.lnk" "$INSTDIR\Commons.exe"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Commons"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
SectionEnd

Section "Uninstall"
	Delete "$SMPROGRAMS\Commons.lnk"
	Delete "$INSTDIR\Commons.exe"
	Delete "$INSTDIR\THIRD-PARTY-NOTICES.txt"
	Delete "$INSTDIR\Uninstall.exe"
	RMDir "$INSTDIR"
	DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
