# Jetbrains Toolbox on WSL

Using "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.

## Intro

Once installed, you may use "Jetbrains Toolbox" from within "WSL" under the "Fedora" distribution.

This image contains minimal Fedora with pre-installed packages: X11 packages, git, gnome-terminal, gedit, and the JDK Adoptium repository configured with dnf package manager.

In addition, "systemctl" is enabled by default, and an unprivileged user named "wsl" exists, with password "wsl".

## Prerequisites

1. Windows 11 or Windows 10 20h2 (10.0.19042.2604) </br>
   Check your windows version on PowerShell:

   ```powershell
   [System.Environment]::OSVersion.Version
   ```

2. PowerShell version 5.1 and above </br>
   Check your PowerShell version:

   ```powershell
   $PSVersionTable.PSVersion
   ```

3. Ensure you are running the right version of WSL: Version 1.1.3.0 and above </br>
   Check your WSL version:

   ```powershell
   wsl --version
   ```

   You can run 'wsl --update' to check for any WSL updates.

## Installation

1. Clone to some directory (let say 'mydir') on your Windows machine, and cd to this folder

   ```powershell
   > mkdir mydir
   > git clone https://github.com/rozidan/jetbrains-toolbox-on-wsl.git
   > cd mydir
   ```

2. build the image with the given Dockerfile and export it with '.tar' file type (let say mytar.tar), then move it into 'mydir' directory.

   > For example you can do that by clone to linux machine and execute the 'build.sh' script

3. execute the jbwsl.ps1 script

   ```powershell
   > .\jbwsl.ps1 -Install -InstallTarPath .\jetbrains-toolbox-wsl.tar
   ```

4. Enter the WSL shell and run 'jentbrains-toolbox'

   ```powershell
   > wsl -d jetbrains-toolbox-wsl
   [wsl@pc1]$ jetbrains-toolbox
   ```

5. In addition, you can create a shortcut on your desktop, that will open the 'Jetbrains Toolbox' from the WSL you just installed

   ```powershell
   >  .\jbwsl.ps1 -Shortcut -ShortcutName 'WSL Jetbrains Toolbox' -ShortcutWslCommand 'jetbrains-toolbox'
   ```

   You can create a shortcut to the 'gnome terminal':

   ```powershell
   >  .\jbwsl.ps1 -Shortcut -ShortcutName 'WSL Terminal' -ShortcutWslCommand 'gnome-terminal'
   ```

   You can create a shortcut to the 'Intellij', after install it with the Jetbrains-Toolbox:

   ```powershell
   >  .\jbwsl.ps1 -Shortcut -ShortcutName 'WSL Intellij' -ShortcutWslCommand 'idea'
   ```

## Installing JDK

Within your WSL terminal, execute to following:

```bash
$ sudo dnf install temurin-17-jdk
```

* The following adoptium-temurin JAVA packages are available:
  * temurin-8-jdk
  * temurin-11-jdk
  * temurin-17-jdk
  * temurin-19-jdk

> The installed JDK's directory is '/usr/lib/jvm/'
>
> Ofcourse you do not have to use those particular JDK builds

## Installing a Root Certificate Authority for Your WSL

Within your WSL console, execute to following:

```bash
$ sudo cp <ca.crt file path> /etc/pki/ca-trust/source/anchors
$ sudo update-ca-trust
```

## Installing a Root Certificate Authority for Your JDK

Within your WSL console, execute to following:

```bash
$ sudo keytool -importcert -alias <alias> -keystore <jdk path>/jre/lib/security/cacerts -storepass changeit -file <ca.crt file path>
```

## Installing Docker Engine

Within your WSL console, execute to following:

```bash
# Set up the repository
$ sudo dnf -y install dnf-plugins-core
$ sudo dnf config-manager \
   --add-repo \
   https://download.docker.com/linux/fedora/docker-ce.repo 
# Install the latest version of Docker Engine, containerd, and Docker Compose
$ sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# enable and start the docker daemoon
$ sudo systemctl enable --now docker
# check it works
$ sudo docker ps
```

In case you what the user 'wsl' to be able to use 'docker' command, just add 'docker' as a user group, then logout and login again

```bash
$ sudo usermod -a -G docker wsl
```

## Browse Windows Files within WSL

You can browse the Windows file system within the WSL by entering the '/mnt/c/' folder
