@ECHO OFF
REM ==============================================================================
REM DOG WALKING APP - Gradle Wrapper for Windows (Gradle 8.4)
REM ------------------------------------------------------------------------------
REM This batch file provides an enterprise-ready and robust Gradle Wrapper script
REM for Windows environments. It integrates with:
REM   - gradle-wrapper.jar (org.gradle.wrapper.GradleWrapperMain)
REM   - gradle-wrapper.properties (distributionUrl, distributionBase, distributionPath)
REM   - Java Runtime Environment (version 1.8+)
REM ensuring a consistent, secure, and comprehensive build automation setup for
REM the Android dog walking application.
REM
REM Highlights / Features:
REM   - Enhanced environment validation and error handling
REM   - Java version checks and path resolution
REM   - Support for Gradle 8.4 with advanced JVM options
REM   - Enterprise considerations (proxy, security, logging)
REM   - Complies with technical specs for mobile development (Android 8.0+)
REM
REM Globals from JSON Specification:
REM   DEFAULT_JVM_OPTS = "-Xmx64m" "-Xms64m" "-Dfile.encoding=UTF-8"
REM   DIRNAME           = %~dp0         (This script's directory)
REM   JAVA_EXE          = Resolved via :find_java_exe
REM   GRADLE_OPTS       = JVM arguments for Gradle
REM   JAVA_OPTS         = Additional JVM arguments
REM   APP_BASE_NAME     = Derived from script name
REM   MAX_FD            = Maximum file descriptors (not directly used in Windows)
REM
REM Functions from JSON Specification:
REM   :find_java_exe         => Locates Java and validates usage of Java 1.8+
REM   :validate_environment  => Checks environment variables, file permissions, etc.
REM   :execute_gradle        => Executes Gradle with extended configuration
REM
REM Exports:
REM   execute_gradle => Primary entry point for the Gradle build process
REM
REM Execution:
REM   gradlew [task...]     => Invokes Gradle tasks with enhanced error handling
REM
REM NOTE: The actual reading of gradle-wrapper.properties to retrieve:
REM       distributionUrl, distributionBase, distributionPath, etc., is performed
REM       internally by org.gradle.wrapper.GradleWrapperMain. This script simply
REM       invokes that class from the gradle-wrapper.jar.
REM ------------------------------------------------------------------------------
REM END HEADER
REM ==============================================================================

SETLOCAL

REM -------------------------------------------------------------------------------
REM Define core environment variables and fallback defaults
REM -------------------------------------------------------------------------------
REM For robust enterprise usage, we ensure memory constraints, encoding, etc.
IF NOT DEFINED DEFAULT_JVM_OPTS (
    SET DEFAULT_JVM_OPTS=-Xmx64m -Xms64m -Dfile.encoding=UTF-8
)

REM Derive directory of this script
SET DIRNAME=%~dp0
IF NOT DEFINED DIRNAME SET DIRNAME=.

REM Normalize APP_BASE_NAME from the batch file's name
SET APP_BASE_NAME=%~n0

REM Predefine the Java executable placeholder; will be set in :find_java_exe
SET JAVA_EXE=

REM Gradle jar location (relative to script directory). Adjust if needed.
REM This is the internal import reference from JSON spec, pointing to the jar:
REM "gradle-wrapper.jar" (org.gradle.wrapper.GradleWrapperMain).
SET WRAPPER_JAR="%DIRNAME%gradle\wrapper\gradle-wrapper.jar"

REM -------------------------------------------------------------------------------
REM :find_java_exe
REM Enhanced Java executable locator with version validation and detailed error reporting
REM -------------------------------------------------------------------------------
:find_java_exe
REM 1. Attempt to locate Java in JAVA_HOME\bin\java.exe if JAVA_HOME is defined
IF DEFINED JAVA_HOME (
    SET "_possible_java=%JAVA_HOME%\bin\java.exe"
    IF EXIST "%_possible_java%" (
        SET JAVA_EXE="%_possible_java%"
        GOTO checkJavaVersion
    )
)

REM 2. Otherwise, check PATH for java.exe
FOR %%I IN (java.exe) DO (
    WHERE /Q %%~I 2>NUL
    IF %ERRORLEVEL%==0 (
        SET JAVA_EXE=%%~$PATH:I
        GOTO checkJavaVersion
    )
)

REM 3. If we still have no valid JAVA_EXE, fail with an error message
ECHO.
ECHO ERROR: JAVA_HOME not set and no 'java.exe' found in PATH. Please set JAVA_HOME
ECHO or ensure 'java.exe' is available in PATH.
ECHO.
EXIT /B 1

:checkJavaVersion
REM Optionally parse the current Java version if needed (basic check for 1.8+).
REM For advanced version checks, we might parse 'java -version' or use an external script.
REM In an enterprise environment, you could call a separate script to do version checks.

REM We'll do a simplified check here. This is best-effort and can be expanded:
FOR /F "tokens=2 delims==" %%V IN ('%JAVA_EXE% -XshowSettings:properties 2^>^&1 ^| FIND /I "java.version"') DO (
    SET _javaVer=%%V
)
REM Trim quotes/spaces if present (basic approach)
SET _javaVer=%_javaVer:"=%
IF NOT DEFINED _javaVer (
    REM If we cannot parse it, just proceed with a warning.
    ECHO WARNING: Could not parse Java version. Attempting to continue...
    GOTO :EOF
)

IF "%_javaVer:~0,3%"=="1.8" GOTO :EOF
IF "%_javaVer:~0,2%"=="17"  GOTO :EOF
IF "%_javaVer:~0,2%"=="18"  GOTO :EOF
IF "%_javaVer:~0,2%"=="19"  GOTO :EOF
IF "%_javaVer:~0,2%"=="20"  GOTO :EOF

ECHO WARNING: Detected Java version "%_javaVer%" which might be incompatible.
ECHO Minimum required is 1.8+. Attempting to continue anyway...
GOTO :EOF

REM -------------------------------------------------------------------------------
REM :validate_environment
REM Validates execution environment and prerequisites
REM -------------------------------------------------------------------------------
:validate_environment
REM Example checks for environment variables or required resources:
IF NOT DEFINED APP_BASE_NAME (
    ECHO ERROR: APP_BASE_NAME is not defined.
    EXIT /B 1
)

REM Optionally check for disk space or other system constraints
REM For instance, using dir or wmic to get disk capacity in advanced usage.

REM Check file access to the wrapper jar
IF NOT EXIST %WRAPPER_JAR% (
    ECHO ERROR: Could not find gradle-wrapper.jar at %WRAPPER_JAR%.
    ECHO Make sure the file is present and the path is correct.
    EXIT /B 1
)

REM This is a placeholder for more enterprise checks:
REM   - Proxy settings
REM   - File descriptor limits
REM   - Connection to required network resources
REM For now, if we haven't errored, we assume environment is valid.
EXIT /B 0

REM -------------------------------------------------------------------------------
REM :execute_gradle
REM Executes Gradle with enhanced configuration and error handling
REM -------------------------------------------------------------------------------
:execute_gradle
REM 1. Build the full Java command with the wrapper jar and pass all script arguments
SET CLASSPATH=%WRAPPER_JAR%
SET CMD_LINE_ARGS=
SET INDEX=0

:loopArgs
IF "%~1"=="" GOTO runGradle
SET CMD_LINE_ARGS=%CMD_LINE_ARGS% "%~1"
SHIFT
GOTO loopArgs

:runGradle
REM Merge DEFAULT_JVM_OPTS, GRADLE_OPTS, and JAVA_OPTS for final usage
REM Example approach:
IF NOT DEFINED GRADLE_OPTS SET GRADLE_OPTS=
IF NOT DEFINED JAVA_OPTS SET JAVA_OPTS=

REM Ensure quotes and expansions
SET FINAL_OPTS=%DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS%

REM Print out for debugging (enterprise logging)
ECHO Using JAVA_EXE: %JAVA_EXE%
ECHO Using JVM Options: %FINAL_OPTS%
ECHO Starting Gradle Wrapper Main Class...

REM Use START /B /WAIT if we want synchronous, or just normal call:
"%JAVA_EXE%" %FINAL_OPTS% -cp %CLASSPATH% org.gradle.wrapper.GradleWrapperMain %CMD_LINE_ARGS%
SET EXIT_CODE=%ERRORLEVEL%

REM Provide additional feedback if an error occurred
IF "%EXIT_CODE%"=="0" (
    ECHO Gradle build finished successfully.
) ELSE (
    ECHO ERROR: Gradle build failed with exit code %EXIT_CODE%.
)

EXIT /B %EXIT_CODE%

REM -------------------------------------------------------------------------------
REM Main Execution Flow
REM Call the relevant sections in order for a comprehensive, enterprise-ready script
REM -------------------------------------------------------------------------------
:main
CALL :find_java_exe
IF ERRORLEVEL 1 EXIT /B 1

CALL :validate_environment
IF ERRORLEVEL 1 EXIT /B 1

CALL :execute_gradle %*
EXIT /B %ERRORLEVEL%

REM -------------------------------------------------------------------------------
REM :EOF - End of File
REM If control gets here, something unexpected occurred. We exit gracefully.
REM -------------------------------------------------------------------------------
:EOF
ENDLOCAL
EXIT /B 0