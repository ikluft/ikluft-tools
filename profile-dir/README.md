# Example .profile/.bashrc split into subdirectories
by Ian Kluft

This directory shows an example of how to split unwieldy .profile and .bashrc scripts into .profile.d and .bashrc.d subdirectories. A lot of people have suggested this before. The approach in my example avoids cluttering the home directory with more dot-files. Instead of making a .bashrc.d directory under the home directory, I also split up the .profile and put them under $HOME/.config/sh .

This is the recommendation of the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/) by the Free Desktop Foundation. The spec suggests putting user configuration files under .config. I originally put the .bashrc under .config/bash, but later consolidated everything under .config/sh so that other POSIX-compatible shells could run the same .profile script. This sets aside bash-specific scripts with a .bash suffix. POSIX shell scripts use a .sh suffix. With these subdirectories, you can split the code from your .bashrc and .profile scripts into as many scripts in the subdirectories as you want or need.

The audience for this example is expected to be people who are comfortable modifying their .bashrc and .profile shell scripts, and consequently noticed these scripts can grow quite large. It's intended for Unix systems such as Linux or BSD running a GNU Bash shell, POSIX-compatible shell or Bourne shell. Among these systems, it should be compatible to run the same setup on your home directories across multiple systems.

$HOME will be abbreviated with a tilde "~" here. They're largely compatible, except when double-quoted.

## Installation instructions
I am not providing an installation script. Obviously customization of one's own shell login environment must be treated with care. And everyone is free to do things a little differently, which makes automation of this installation a challenge. Also, it's only a few steps that people who are ready for it should have no problem with.

First, get a copy of the profile-dir directory tree from my ikluft-tools repository. You can use the git-clone or tarball methods to get a copy of the repository. You should place these files either under your home directory or at least on the same mount-point as your home directory. This is to avoid a situation where your .bashrc or .profile may not be mounted when you log in, causing the login scripts to fail.

Next, save and set aside your ~/.bashrc, ~/.profile, ~/.bash_profile and/or ~/.bash_login, whichever ones exist in your home directory. In case of a problem, you should be ready to copy them back and start over. You'll also use these to copy snippets of code from your .bashrc and .profile (or ~/.bash_profile or ~/.bash_login, whichever profile script you originally had) to the dot-file subdirectories.

Then make symbolic links pointing your home directory scripts into the git sources. I'll abbreviate the source directory as _srcdir_. If you used the git clone method, you can update it from the git repository directly after changes occur.

For those who need a refresher on how to create symbolic links, use "ln -s target origin". See the [ln(1) manual](https://www.gnu.org/software/coreutils/manual/coreutils.html#ln-invocation). I'm mainly mentioning it here to include the reminder that the ln command arguments may appear backwards. Links below are in the order "origin → target".

* create symlink: ~/.bashrc → _srcdir_/dot-bashrc
* create symlink: ~/.profile → _srcdir_/dot-profile
* create directories: ~/.config/sh ~/.config/sh/bashrc.d ~/.config/sh/profile.d
* create symlink: ~/.config/sh/common.sh → _srcdir_/config-sh/common.sh _(note: .bashrc and .profile will refuse to run without this)_
* create symlink: ~/.config/sh/pathfilter → _srcdir_/config-sh/pathfilter/pathfilter.pl (or alternate implementation, see below)
* create symlinks: ~/.config/sh/bashrc.d/* → _srcdir_/config-sh/bashrc.d/*
* create symlinks: ~/.config/sh/profile.d/* → _srcdir_/config-sh/profile.d/*

Finally, use your original .bashrc and .profile to create your own local profile and bashrc scripts in the new subdirectories, alongside the symlinks to the git sources. Follow these rules:

* name each script in bashrc.d and profile.d starting with numeric digits to make it obvious what order they should run in. I used 3 digits in my example, starting with 0 for core code (such as [002-terminal.sh](config-sh/profile.d/002-terminal.sh)) and 1 for common higher-level application settings (such as [100-dev-gcc.sh](config-sh/profile.d/100-dev-gcc.sh)). I started scripts with the digit 2 or higher for my own local scripts - but those aren't checked into the git example. You can separate your own local scripts from the git-supplied files the same way.
* Use the .sh suffix for scripts with Bourne/POSIX shell code and .bash for GNU Bash code.
* bashrc code snippets should go into files in ~/.config/sh/bashrc.d
* profile code snippets should go into files in ~/.config/sh/profile.d
* Some scripts in the profile.d directory actually should be executed for login shells (which run .profile) and other interactive shells (for which bash runs .bashrc). Rather than duplicate the files, you can put a text file with a .import suffix in the bashrc.d directory with a list of names of the files from the profile.d directory which should be run. Name the import file with leading numeric digits to indicate the order in which they should run. See the example in [000-common.import](config-sh/bashrc.d/000-common.import) .

## Alternative pathfilter implementation
If you have [Rust](https://www.rust-lang.org/) installed, you can compile a faster alternative implementation of the pathfilter program used by this profile/bashrc system.
First compile the pathfilter program with these commands in the _srcdir_ directory used above, where source code from GitHub was placed.

    cd _srcdir_/config-sh/pathfilter/pathfilter-rust/
    cargo build

Then go back to your home directory and substitute the symbolic link for pathfilter as follows:

* create symlink: ~/.config/sh/pathfilter → _srcdir_/config-sh/pathfilter/pathfilter-rust/target/debug/pathfilter-rust

## Files
<p>
	├── <a href="config-sh/">config-sh</a> - directory with files to symlink in your ~/.config/sh directory<br>
	│   ├── <a href="config-sh/bashrc.d/">bashrc.d</a> - files to symlink in your ~/.config/sh/bashrc.d directory<br>
	│   │   ├── <a href="config-sh/bashrc.d/000-common.import">000-common.import</a><br>
	│   │   └── <a href="config-sh/bashrc.d/101-flatpak.bash-example">101-flatpak.bash-example</a><br>
	│   ├── <a href="config-sh/common.sh">common.sh</a> - common code used by both ~/.bashrc and ~/.profile<br>
	│   ├── <a href="config-sh/pathfilter/">pathfilter</a> - source code for Perl and Rust implementations of pathfilter<br>
	│   │   ├── <a href="config-sh/pathfilter/pathfilter.pl">pathfilter.pl</a> - Perl implementation of pathfilter<br>
	│   │   └── <a href="config-sh/pathfilter/pathfilter-rust/">pathfilter-rust</a> - Rust implementation of pathfilter (requires compilation)<br>
	│   └── <a href="config-sh/profile.d/">profile.d</a> - files to symlink in your ~/.config/sh/profile.d directory<br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/001-shell.sh">001-shell.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/002-terminal.sh">002-terminal.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/003-pathfilter.sh">003-pathfilter.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/004-color.sh">004-color.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/005-shell.bash">005-shell.bash</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/020-timezone.sh">020-timezone.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/021-vimode.sh">021-vimode.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/100-dev-gcc.sh">100-dev-gcc.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/100-dev-go.sh">100-dev-go.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; ├── <a href="config-sh/profile.d/100-dev-perl.sh">100-dev-perl.sh</a><br>
	│   &nbsp;&nbsp;&nbsp; └── <a href="config-sh/profile.d/100-dev-rust.sh">100-dev-rust.sh</a><br>
	├── <a href="dot-bashrc">dot-bashrc</a> - file to symlink from your ~/.bashrc script<br>
	├── <a href="dot-profile">dot-profile</a> - file to symlink from your ~/.profile script<br>
	└── <a href="README.md">README.md</a><br>
</p>
