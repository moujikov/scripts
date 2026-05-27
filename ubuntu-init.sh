#!/usr/bin/env bash

# Run: curl -fsSL https://github.com/moujikov/scripts/raw/main/ubuntu-init.sh | bash -s
# optionally provide a custom SSH port as the first argument (e.g. ... | bash -s -- 43210)

SSH_PORT=${1:-22}

#### Update & upgrade ####
apt -y update
apt -y full-upgrade
apt -y install --no-install-recommends bat net-tools fail2ban

ln -s /usr/bin/batcat /usr/local/bin/bat

#### Set up working user ####

adduser andrey --disabled-password --comment 'Andrey Moujikov'
usermod -aG sudo andrey

cat <<-'EOF' >/etc/sudoers.d/andrey 
	Defaults:andrey env_keep += "PWD"
	andrey ALL=(ALL:ALL) NOPASSWD:ALL
EOF

# Add SSH keys:
install -m 700 -o andrey -g andrey -d /home/andrey/.ssh 
install -m 600 -o andrey -g andrey /dev/null /home/andrey/.ssh/authorized_keys
cat <<-'EOF' >/home/andrey/.ssh/authorized_keys
	ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA6WCh1yZ8AWMxYP7sgLTZy8KTWxgNzLthLS+SR+OMF VPS/VDS general ssh keys – andrey@macbook
	ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILq0eKhu+Qco7zXl3nfbtgsnpiUoaVBrmeaHNaC+Z0mk VPS/VDS general ssh keys – andrey@mobile
EOF

# Fix bash prompt and a few other things:
echo $'\n\n' | tee >/dev/null -a /home/andrey/.bashrc /root/.bashrc 

sed '/^###_mark_###/,$d' -i'' /home/andrey/.bashrc /root/.bashrc 
cat <<-'EOF' | tee >/dev/null -a /home/andrey/.bashrc /root/.bashrc 
	###_mark_### !!! Everything below this line is managed by a script – do not edit manually !!!

	if [[ "$TERM" == *-color || "$TERM" == *-256color ]]; then
	    [[ $EUID -eq 0 ]] && USER_COLOR='01;31' || USER_COLOR='01'
	    PS1='\n\[\033['"$USER_COLOR"'m\]┌──\u@\h\[\033[00m\]:\[\033[36m\]$PWD\[\033[00m\] \n\[\033['"$USER_COLOR"'m\]\$\[\033[00m\] '
	fi

	export BAT_THEME=gruvbox-dark

	alias bal='bat --paging=never --language log --plain'
EOF

# Set up nano keybindings for andrey and root:
install -m 644 -o andrey -g andrey /dev/null /home/andrey/.nanorc
cat <<-'EOF' | tee >/dev/null /home/andrey/.nanorc /root/.nanorc
	bind M-b prevword main
	bind M-f nextword main
	bind ^W chopwordleft main
	bind M-d chopwordright main
	bind ^U cut main
	bind ^K zap main
	bind ^_ undo main
	bind M-r redo main
	bind ^C copy main
	bind ^Y paste main
EOF

# Add iTerm shell integration:
curl -L https://iterm2.com/misc/install_shell_integration.sh | sudo -u andrey bash


#### Secure SSH access ####
install -m 600 /dev/null /etc/ssh/sshd_config.d/00-secure-ssh.conf
cat <<-EOF  >/etc/ssh/sshd_config.d/00-secure-ssh.conf
	Port $SSH_PORT
	PermitRootLogin no
	PasswordAuthentication no
	PubkeyAuthentication yes
	AcceptEnv TZ
	ClientAliveInterval 60
	ClientAliveCountMax 3
EOF


#### Disable root access ####
passwd -dl root
rm -rf /root/.ssh


#### Update Ubuntu startup message ####

# Don't show news, help and other useless stuff:
sed '/^ENABLED=/s/1/0/' -i'' /etc/default/motd-news
chmod -x /etc/update-motd.d/10-help-text
chmod -x /etc/update-motd.d/50-motd-news
chmod -x /etc/update-motd.d/91-contract-ua-esm-status

# Disable Expanded Security Maintenance messages
touch /var/lib/update-notifier/hide-esm-in-motd
# and rebuild cached messages
/usr/lib/update-notifier/update-motd-updates-available --force

# But add uptime info:
install -m 700 /dev/null /etc/update-motd.d/99-uptime
cat <<-'EOF' >/etc/update-motd.d/99-uptime
	#!/bin/sh
	echo Uptime: `/usr/bin/uptime`; echo
EOF


#### Reboot ####
reboot
