REM @echo off
IF "%1%"=="64" ECHO "BUILDING 64bit solution" 
IF NOT "%1%"=="64" ECHO "BUILDING 32bit solution"

SET OS_MODE=
IF "%1%"=="64" SET OS_MODE= Win64
  
SET PROGRAMFILES_DIR_X86=%programfiles(x86)%
if NOT EXIST "%PROGRAMFILES_DIR_X86%" SET PROGRAMFILES_DIR_X86=%programfiles%
SET PROGRAMFILES_DIR=%programfiles%

REM Find CMake  
SET CMAKE="cmake.exe"
IF EXIST "%PROGRAMFILES_DIR_X86%\CMake 2.8\bin\cmake.exe" SET CMAKE="%PROGRAMFILES_DIR_X86%\CMake 2.8\bin\cmake.exe"

IF EXIST "CMakeCache.txt" del CMakeCache.txt

REM Find Visual Studio or Msbuild
SET VS2005="%VS80COMNTOOLS%..\IDE\devenv.exe"
SET VS2008="%VS90COMNTOOLS%..\IDE\devenv.exe"
SET VS2010="%VS100COMNTOOLS%..\IDE\devenv.exe"
SET MSBUILD35="%windir%\Microsoft.NET\Framework\v3.5\MSBuild.exe"

IF EXIST %MSBUILD35% SET DEVENV=%MSBUILD35%
IF EXIST %VS2005% SET DEVENV=%VS2005% 
IF EXIST %VS2008% SET DEVENV=%VS2008%

IF "%2%"=="gpu" goto SET_BUILD_TYPE
IF EXIST %VS2010% SET DEVENV=%VS2010%

:SET_BUILD_TYPE
IF %DEVENV%==%MSBUILD35% SET BUILD_TYPE=/property:Configuration=Release
IF %DEVENV%==%VS2005% SET BUILD_TYPE=/Build Release
IF %DEVENV%==%VS2008% SET BUILD_TYPE=/Build Release
IF %DEVENV%==%VS2010% SET BUILD_TYPE=/Build Release

IF %DEVENV%==%MSBUILD35% SET CMAKE_CONF="Visual Studio 8 2005%OS_MODE%"
IF %DEVENV%==%VS2005% SET CMAKE_CONF="Visual Studio 8 2005%OS_MODE%"
IF %DEVENV%==%VS2008% SET CMAKE_CONF="Visual Studio 9 2008%OS_MODE%"
IF %DEVENV%==%VS2010% SET CMAKE_CONF="Visual Studio 10%OS_MODE%"

SET CMAKE_CONF_FLAGS= -G %CMAKE_CONF% ^
-DBUILD_DOCS:BOOL=FALSE ^
-DBUILD_TESTS:BOOL=FALSE ^
-DBUILD_NEW_PYTHON_SUPPORT:BOOL=FALSE ^
-DEMGU_ENABLE_SSE:BOOL=TRUE ^
-DCMAKE_INSTALL_PREFIX="%TEMP%" 

IF NOT "%4%"=="openni" GOTO END_OF_OPENNI

:WITH_OPENNI
SET OPENNI_LIB_DIR=%OPEN_NI_LIB%
IF "%OS_MODE%"==" Win64" SET OPENNI_LIB_DIR=%OPEN_NI_LIB64%
SET OPENNI_PS_BIN_DIR=%OPENNI_LIB_DIR%\..\..\PrimeSense\Sensor\Bin
IF "%OS_MODE%"==" Win64" SET OPENNI_PS_BIN_DIR=%OPENNI_LIB_DIR%\..\..\PrimeSense\Sensor\Bin64

IF EXIST "%OPENNI_LIB_DIR%" SET CMAKE_CONF_FLAGS=%CMAKE_CONF_FLAGS% ^
-DWITH_OPENNI:BOOL=TRUE ^
-DOPENNI_INCLUDE_DIR="%OPEN_NI_INCLUDE:\=/%" ^
-DOPENNI_LIB_DIR="%OPENNI_LIB_DIR:\=/%" ^
-DOPENNI_PRIME_SENSOR_MODULE_BIN_DIR="%OPENNI_PS_BIN_DIR:\=/%"
:END_OF_OPENNI


IF "%5%"=="doc" ^
SET CMAKE_CONF_FLAGS=%CMAKE_CONF_FLAGS% -DEMGU_CV_DOCUMENTATION_BUILD:BOOL=TRUE 

IF NOT "%2%"=="gpu" GOTO END_OF_GPU

:WITH_GPU
REM Find cuda
SET CUDA_SDK_DIR=%CUDA_PATH%.
IF EXIST "%CUDA_PATH%" SET CMAKE_CONF_FLAGS=%CMAKE_CONF_FLAGS% ^
-DWITH_CUDA:BOOL=TRUE ^
-DCUDA_VERBOSE_BUILD:BOOL=TRUE ^
-DCUDA_TOOLKIT_ROOT_DIR="%CUDA_SDK_DIR:\=/%" ^
-DCUDA_SDK_ROOT_DIR="%CUDA_SDK_DIR:\=/%"
:END_OF_GPU

IF "%3%"=="intel" GOTO INTEL_COMPILER
IF NOT "%3%"=="intel" GOTO VISUAL_STUDIO

:INTEL_COMPILER
REM Find Intel Compiler 
SET INTEL_DIR=%ICPP_COMPILER12%bin
SET INTEL_ENV=%ICPP_COMPILER12%bin\iclvars.bat
SET INTEL_ICL=%ICPP_COMPILER12%bin\ia32\icl.exe
IF "%OS_MODE%"==" Win64" SET INTEL_ICL=%ICPP_COMPILER12%bin\intel64\icl.exe
SET INTEL_TBB=%TBB30_INSTALL_DIR%\include
IF "%OS_MODE%"==" Win64" SET INTEL_IPP=%ICPP_COMPILER12%redist\intel64\ipp
SET ICPROJCONVERT=%PROGRAMFILES_DIR_X86%\Common Files\Intel\shared files\ia32\Bin\ICProjConvert120.exe

REM initiate the compiler enviroment
@echo on
REM IF "%OS_MODE%"=="" CALL "%INTEL_ENV%" ia32
REM IF "%OS_MODE%"==" WIN64" CALL "%INTEL_ENV%" intel64

REM SET INTEL_ICL_CMAKE=%INTEL_ICL:\=/%

IF EXIST "%INTEL_DIR%" SET CMAKE_CONF_FLAGS=^
-DWITH_TBB:BOOL=TRUE ^
-DTBB_INCLUDE_DIR="%INTEL_TBB:\=/%" ^
-DWITH_IPP:BOOL=TRUE ^
-DCV_ICC:BOOL=TRUE ^
%CMAKE_CONF_FLAGS%

REM create visual studio project
%CMAKE% %CMAKE_CONF_FLAGS%

REM convert the project to use intel compiler 
IF EXIST "%ICPROJCONVERT%" "%ICPROJCONVERT%" emgucv.sln /IC
REM exclude tesseract_wordrec, tesseract_ccstruct, tesseract_ccmain and libjpeg
REM these projects create problems for intel compiler
IF EXIST "%ICPROJCONVERT%" "%ICPROJCONVERT%" emgucv.sln ^
Emgu.CV.Extern\libgeotiff\libgeotiff-1.3.0\libxtiff\xtiff.icproj ^
Emgu.CV.Extern\libgeotiff\libgeotiff-1.3.0\geotiff_archive.icproj ^
Emgu.CV.Extern\tesseract\libtesseract\tesseract-ocr\ccstruct\tesseract_ccstruct.icproj ^
Emgu.CV.Extern\tesseract\libtesseract\tesseract-ocr\wordrec\tesseract_wordrec.icproj ^
/VC

GOTO BUILD

:VISUAL_STUDIO
@echo on
%CMAKE% %CMAKE_CONF_FLAGS% -DWITH_IPP:BOOL=FALSE  

:BUILD

SET BUILD_PROJECT=
IF "%6%"=="package" SET BUILD_PROJECT= /project PACKAGE 

%DEVENV% %BUILD_TYPE% emgucv.sln %BUILD_PROJECT% /out "%CD%\build.log"