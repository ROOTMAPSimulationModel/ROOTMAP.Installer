# ROOTMAP.Installer

TODO: update this readme! Link to readmes in git submodules?

## How to build

Compile it with Visual Studio 2017. Other IDEs (Visual Studio 2019, Visual Studio 2015, Jetbrains Rider etc.) may work but have not been tested. All dependencies are will be automatically obtained via NuGet package.

### Generating a self-signed certificate for code signing

*Self-signed certs don't provide any verifiable trust to the end user, but they're good to use as a placeholder while developing automated code signing CI tasks.*

Run this at an **elevated** Powershell prompt, using your own name of course:

```
$loc = "Cert:\LocalMachine\My"
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=Mike Airey, O=Open source developer, S=Tasmania, C=AU" -KeyUsage DigitalSignature -FriendlyName "Mike Airey" -CertStoreLocation $loc
```
`$cert` will look like this:
```
   PSParentPath: Microsoft.PowerShell.Security\Certificate::LocalMachine\My

Thumbprint                                Subject
----------                                -------
F2[THUMBPRINT]0000000000000000000000006B  CN=Mike Airey, O=Open source developer, S=Tasmania, C=AU
```
Declare the path to the certificate:
```
$path = $loc + "\" + $cert.Thumbprint
```
Create a password: run this command, which will prompt you to enter a password
```
$pwd = ConvertTo-SecureString -AsPlainText -Force
```
Export the certificate to a PFX file in the current directory:
```
Export-PfxCertificate -cert $path -FilePath .\cert.pfx -Password $pwd
```
Store the password securely in a password manager.
