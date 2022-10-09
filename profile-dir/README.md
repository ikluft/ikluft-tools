# Example .profile/.bashrc split into subdirectories
by Ian Kluft

This directory shows an example of how to split unwieldy .profile and .bashrc scripts into subdirectories. A lot of people have suggested this before. The approach in my example avoids cluttering the home directory with more dot-files. Instead of making a .bashrc.d directory under the home directory, I also split up the .profile and put them under $HOME/.config/sh .

This is the recommendation of the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/) by the Free Desktop Foundation. The spec suggests putting user configuration files under .config. I originally put the .bashrc under .config/bash, but later consolidated everything under .config/sh so that other POSIX-compatible shells could run the same .profile script. This sets aside bash-specific scripts with a .bash suffix. POSIX shell scripts use a .sh suffix.

The audience for this example is expected to be people who are comfortable modifying their .bashrc and .profile shell scripts, and consequently noticed these scripts can grow quite large. It's intended for Unix systems such as Linux or BSD running a GNU Bash shell, POSIX-compatible shell or Bourne shell. Among these systems, it should be compatible to run the same setup on your home directories across multiple systems.

$HOME will be abbreviated with a tilde "~" here. They're largely compatible, except when double-quoted.

## Installation instructions
First, get a copy of the profile-dir directory tree from my ikluft-tools repository. You can use the git-clone or tarball methods to get a copy of the repository. You should place these files either under your home directory or at least on the same mount-point as your home directory. This is to avoid a situation where your .bashrc or .profile may not be mounted when you log in, causing the login scripts to fail.

Next, save and set aside your ~/.bashrc, ~/.profile, ~/.bash_profile and/or ~/.bash_login, whichever ones exist in your home directory. In case of a problem, you should be ready to copy them back and start over. You'll also use these to copy snippets of code from your .bashrc and .profile (or ~/.bash_profile or ~/.bash_login, whichever profile script you originally had) to the dot-file subdirectories.

Then make symbolic links pointing your home directory scripts into the git sources. I'll abbreviate the source directory as _srcdir_. If you used the git clone method, you can update it from the git repository directly after changes occur.

* create a symlink: ~/.bashrc → _srcdir_/dot-bashrc
* create a symlink: ~/.profile → _srcdir_/dot-profile
* create directories: ~/.config/sh ~/.config/sh/bashrc.d ~/.config/sh/profile.d
* create symlink: ~/.config/sh/pathmunge.pl → _srcdir_/config-sh/pathmunge.pl
* create symlinks: ~/.config/sh/bashrc.d/* → _srcdir_/config-sh/bashrc.d/*
* create symlinks: ~/.config/sh/profile.d/* → _srcdir_/config-sh/profile.d/*

Finally, use your original .bashrc and .profile to create your own local profile and bashrc scripts in the new subdirectories, alongside the symlinks to the git sources. Follow these rules:

* name each script in bashrc.d and profile.d starting with numeric digits to make it obvious what order they should run in. I used 3 digits in my example, starting with 0 for core code (such as [002-terminal.sh](config-sh/profile.d/002-terminal.sh)) and 1 for common higher-level application settings (such as [100-dev-gcc.sh](config-sh/profile.d/100-dev-gcc.sh)). I started scripts with the digit 2 or higher for my own local scripts - but those aren't checked into the git example. You can separate your own local scripts from the git-supplied files the same way.
* Use the .sh suffix for scripts with Bourne/POSIX shell code and .bash for GNU Bash code.
* bashrc code snippets should go into files in ~/.config/sh/bashrc.d
* profile code snippets should go into files in ~/.config/sh/profile.d
* Some scripts in the profile.d directory actually should be executed for login shells (which run .profile) and other interactive shells (for which bash runs .bashrc). Rather than duplicate the files, you can put a text file with a .import suffix in the bashrc.d directory with a list of names of the files from the profile.d directory which should be run. Name the import file with leading numeric digits to indicate the order in which they should run. See the example in [000-common.import](config-sh/bashrc.d/000-common.import) .

## Files
<p>
	├── <a href="./config-sh/">config-sh</a> - directory with files to symlink in your ~/.config/sh directory<br>
	│   ├── <a href="./config-sh/bashrc.d/">bashrc.d</a> - files to symlink in your ~/.config/sh/bashrc.d directory<br>
	│   │   ├── <a href="./config-sh/bashrc.d/000-common.import">000-common.import</a><br>
	│   │   └── <a href="./config-sh/bashrc.d/101-flatpak.bash-example">101-flatpak.bash-example</a><br>
	│   ├── <a href="./config-sh/pathmunge.pl">pathmunge.pl</a> - script to process PATH entries and prevent duplication of entries<br>
	│   └── <a href="./config-sh/profile.d/">profile.d</a> - files to symlink in your ~/.config/sh/profile.d directory<br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/001-shell.sh">001-shell.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/002-terminal.sh">002-terminal.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/003-pathmunge.sh">003-pathmunge.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/004-color.sh">004-color.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/005-shell.bash">005-shell.bash</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/020-timezone.sh">020-timezone.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/021-vimode.sh">021-vimode.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/100-dev-gcc.sh">100-dev-gcc.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/100-dev-go.sh">100-dev-go.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="./config-sh/profile.d/100-dev-perl.sh">100-dev-perl.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; └── <a href="./config-sh/profile.d/100-dev-rust.sh">100-dev-rust.sh</a><br>
	├── <a href="./dot-bashrc">dot-bashrc</a> - file to symlink from your ~/.bashrc script<br>
	├── <a href="./dot-profile">dot-profile</a> - file to symlink from your ~/.profile script<br>
	└── <a href="./README.md">README.md</a><br>
</p>