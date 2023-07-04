#-------------------------------------------------------------------------------------------------------------------------
# Create RefreshNow.exe
# Version 1.0 Jorrit van Eijk - AppSense
# Version 1.1 Thomas Schoepf - VSI IT-Solutions GmbH
#             Added get latest .NET Full Version to support newer OS without .NET 2 installed         
#
# Description:
# Creates an empty C# executable that can be leveraged by AppSense Environment Manager to create process start triggers.
# This eliminates the need to copy an empty executable to endpoints, and instead generates it on the fly based on e.g.
# Computer Startup trigger
#
#-------------------------------------------------------------------------------------------------------------------------

#Compile the CSharp code
function Compile-CSharp (
  [string] $code,
  #$frameworkVersion="v2.0.50727",
  [string] $frameworkVersion,
  [string] $OutputEXE,
  [Array] $references
)
{
    $codeProvider = new-object Microsoft.CSharp.CSharpCodeProvider
    $compilerParamerters = New-Object System.CodeDom.Compiler.CompilerParameters
    $compilerParamerters.CompilerOptions = "/t:winexe"
    foreach ($reference in $references) {
      $compilerParamerters.ReferencedAssemblies.Add( $reference );
    }
    $compilerParamerters.GenerateInMemory = $false
    $compilerParamerters.GenerateExecutable = $true
    
    $compilerParamerters.OutputAssembly =  $OutputEXE
    $compiledCode = $codeProvider.CompileAssemblyFromSource(
      $compilerParamerters,
      $code
    )
 
    if ( $compiledCode.Errors.Count)
    {
        $codeLines = $code.Split("`n");
        foreach ($compilerError in $compiledCode.Errors)
        {
            write-host "Error: $($codeLines[$($compilerError.Line - 1)])"
            write-host $compilerError
        }
        throw "Errors encountered while compiling code"
    }
}

function Sign-Executable {
    param (
        [string]$ExecutablePath,
        [string]$PfxFilePath,
        [string]$PfxPassword
    )

    if (-not (Test-Path $PfxFilePath)) {
        Write-Host "PFX file not found."
        return
    }

    try {
 $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = "C:\Program Files (x86)\Microsoft SDKs\ClickOnce\SignTool\signtool.exe"
        $process.StartInfo.Arguments = "sign /f `"$PfxFilePath`" /p `"$PfxPassword`" `"$ExecutablePath`""
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.CreateNoWindow = $true

        $process.Start() | Out-Null
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -eq 0) {
            Write-Host "Executable signed successfully."
        } else {
            Write-Host "Error signing the executable:"
            Write-Host $output
        }
    } catch {
        Write-Host "Error signing the executable: $_"
    }
}



#-----------------------------------------------------------------------------------------------------------

#the actual csharp code, actually do nothing for one second and then exit

$csharp = @'
    using System;
    namespace RefreshNow 
    { 
        static class Program 
        { 
            static void Main() 
            { 
                System.Threading.Thread.Sleep(1000); 
            } 
       } 
   }
'@

#get the current program files directory
$strProgramFilesPath = $env:programfiles
$strOutputFilePath = "$strProgramFilesPath\AppSense\Environment Manager\Agent\Addon"

#get the current .NET Full Version for compile
$NETFullVersion = [System.Runtime.InteropServices.RuntimeEnvironment]::GetSystemVersion()

If (Test-Path $strOutputFilePath)
 {
# do noting
 }
Else
 {New-Item $strOutputFilePath -type directory}
#compile the code
compile-csharp  -code $csharp -references 'System.Windows.Forms.dll' -outputexe "$strOutputFilePath\refreshnow.exe" -frameworkVersion $NETFullVersion

#Sign Executable
$executablePath = "$strOutputFilePath\refreshnow.exe"
$pfxFilePath = "C:\temp\refreshnow.pfx"
$pfxPassword = "Kennwort01"

Sign-Executable -ExecutablePath $executablePath -PfxFilePath $pfxFilePath -PfxPassword $pfxPassword

