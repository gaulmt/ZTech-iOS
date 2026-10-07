@echo off
chcp 65001 >nul
title ZTech iOS - Day Code Len GitHub Actions
cd /d "%~dp0"

echo ========================================================
echo   ZTECH iOS - TU DONG PUSH LEN GITHUB ACTIONS DE BUILD
echo ========================================================
echo.

if not exist ".git" (
    git init
    git branch -M main
)

git add .
git commit -m "Build ZTech iOS Package (.deb Rootless/Rootful & .tipa)"

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo Nhap link Repo GitHub cua ban ^(vi du: https://github.com/ten-ban/ztech-ios.git^):
    set /p REPO_URL="> Link GitHub Repo: "
    git remote add origin "%REPO_URL%"
)

echo.
echo Dang day code len GitHub...
git push -u origin main --force

echo.
echo ========================================================
echo   HOAN TAT! Hay mo tab "Actions" tren GitHub Repo cua ban
echo   Sau ~2 phut, tai file "ZTech-iOS-Packages.zip" chua:
echo     1. ZTech_Rootless_arm64.deb  ^(Cho Dopamine / palera1n Rootless^)
echo     2. ZTech_Rootful_arm.deb     ^(Cho Checkra1n / Unc0ver / Rootful^)
echo     3. ZTech_TrollStore.tipa     ^(Cho TrollStore^)
echo     4. ZTech_App.ipa             ^(Cho Sideload / Filza^)
echo ========================================================
pause
