# escape=`
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019
# Restore the default Windows shell for correct batch processing.
 SHELL ["cmd", "/S", "/C"]

ADD https://aka.ms/vs/16/release/vs_buildtools.exe vs_buildtools.exe
RUN vs_buildtools.exe --quiet --wait --norestart --nocache `
    --installPath C:\BuildTools `
    --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended `
    && powershell -Command "if ($err = dir $Env:TEMP -Filter dd_setup_*_errors.log | where Length -gt 0 | Get-Content) { throw $err }" `
    && del vs_BuildTools.exe `
    # Cleanup
    && rmdir /S /Q "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" `
    && powershell Remove-Item -Force -Recurse "%TEMP%\*" `
    && rmdir /S /Q "%ProgramData%\Package Cache"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG CUDA_VERSION=10.2
ENV CUDA_VERSION=${CUDA_VERSION}
#See https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html for a list of cuda subpackages and names
ARG CUDA_SUBPACKAGES=nvcc,cublas,cublas_dev,cudart,cufft,cufft_dev,curand,curand_dev,cusolver,cusolver_dev,cusparse,cusparse_dev,nvgraph,nvgraph_dev,npp,npp_dev,nvrtc,nvrtc_dev,nvml_dev

#Install CUDA
RUN Invoke-WebRequest `
            -UseBasicParsing `
            -Uri http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_441.22_win10.exe `
            -OutFile cuda.exe; `
    $subPackages=$Env:CUDA_SUBPACKAGES.Split(',') | % {[String] \"${_}_${Env:CUDA_VERSION}\"}; `
    Start-Process -FilePath cuda.exe -Wait -NoNewWindow -ArgumentList ([String[]]('-s',$subPackages)); `
#extract targets/props files from cuda installer. Visual studio integration cannot be installed since the containet only has build tools.
#Use 7zip because all powershell commands fails to expand the cuda installer as an archive
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco install 7zip -y --no-progress; `
    7z e \"-oc:\BuildTools\MSBuild\Microsoft\VC\v160\BuildCustomizations\" cuda.exe \"CUDAVisualStudioIntegration/extras/visual_studio_integration/MSBuildExtensions/*.*\"; `
    choco uninstall 7zip 7zip.install -y; `
    Remove-Item -Force cuda.exe;
# Use developer command prompt and start PowerShell if no other command specified.
ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&"]

# Default to PowerShell if no other command specified.
CMD ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
