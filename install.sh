#!/usr/bin/env bash
# chicago95-artix -- automated rice + pentest setup for Artix Linux XFCE
# usage: bash install.sh

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/dots" && pwd)"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[-]\033[0m %s\n' "$*"; exit 1; }

pkg() {
    for p in "$@"; do
        sudo pacman -S --needed --noconfirm "$p" 2>/dev/null || warn "package not found, skipping: $p"
    done
}

aur() {
    for p in "$@"; do
        yay -S --needed --noconfirm "$p" 2>/dev/null || warn "aur package not found, skipping: $p"
    done
}

[[ $EUID -eq 0 ]] && die "do not run as root"

# ── blackarch repo ────────────────────────────────────────────────────────────
setup_blackarch() {
    if grep -q '\[blackarch\]' /etc/pacman.conf; then
        log "blackarch repo already configured"
        return
    fi
    log "installing blackarch keyring and repo"
    curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh
    echo "5ea40d49ecd14c2e024deecf90605426db97ea0c  /tmp/strap.sh" | sha1sum -c - \
        || die "blackarch strap.sh checksum failed -- download it manually"
    sudo bash /tmp/strap.sh
    rm /tmp/strap.sh
}

# ── yay ───────────────────────────────────────────────────────────────────────
setup_yay() {
    if command -v yay &>/dev/null; then
        log "yay already installed"
        return
    fi
    log "installing yay"
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
}

# ── chicago95 theme ───────────────────────────────────────────────────────────
setup_chicago95() {
    log "installing chicago95 theme"
    aur chicago95-gtk-theme-git chicago95-icon-theme-git ttf-ms-fonts

    log "applying xfce theme settings"
    xfconf-query -c xsettings -p /Net/ThemeName          -s "Chicago95" --create -t string
    xfconf-query -c xsettings -p /Net/IconThemeName       -s "Chicago95" --create -t string
    xfconf-query -c xsettings -p /Gtk/CursorThemeName     -s "Chicago95 Cursor Black" --create -t string
    xfconf-query -c xsettings -p /Gtk/FontName            -s "Sans 8" --create -t string
    xfconf-query -c xsettings -p /Xft/Antialias           -s "0" --create -t int
    xfconf-query -c xsettings -p /Xft/HintStyle           -s "hintnone" --create -t string

    xfconf-query -c xfwm4 -p /general/theme               -s "Chicago95" --create -t string
    xfconf-query -c xfwm4 -p /general/title_font          -s "Sans Bold 8" --create -t string
    xfconf-query -c xfwm4 -p /general/button_layout       -s "O|SHMC" --create -t string

    # desktop
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVGA-1/workspace0/color-style \
        -s 0 --create -t int
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVGA-1/workspace0/rgba1 \
        -s "0.000000;0.000000;0.501961;1.000000" --create -t string

    log "chicago95 applied"
}

# ── panel (windows 95 taskbar) ────────────────────────────────────────────────
setup_panel() {
    log "configuring panel as win95 taskbar"
    xfconf-query -c xfce4-panel -p /panels -n -t int -s 1
    xfconf-query -c xfce4-panel -p /panels/panel-1/position       -s "p=8;x=0;y=0" --create -t string
    xfconf-query -c xfce4-panel -p /panels/panel-1/size           -s 28 --create -t int
    xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked -s true --create -t bool
    xfconf-query -c xfce4-panel -p /panels/panel-1/length         -s 100 --create -t int
    xfconf-query -c xfce4-panel -p /panels/panel-1/length-adjust  -s true --create -t bool
    xfconf-query -c xfce4-panel -p /panels/panel-1/background-style -s 1 --create -t int
    xfconf-query -c xfce4-panel -p /panels/panel-1/background-color \
        -s "#c0c0c0" --create -t string
}

# ── dotfiles ──────────────────────────────────────────────────────────────────
deploy_dots() {
    log "deploying dotfiles"

    for src in "$DOTFILES_DIR"/.*; do
        [[ "$(basename "$src")" =~ ^\.(\.)?$ ]] && continue
        dest="$HOME/$(basename "$src")"
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            warn "backing up $dest -> ${dest}.bak"
            mv "$dest" "${dest}.bak"
        fi
        ln -sf "$src" "$dest"
        log "linked $(basename "$src")"
    done

    # .config subdirs
    mkdir -p "$HOME/.config"
    for src in "$DOTFILES_DIR"/.config/*/; do
        name="$(basename "$src")"
        dest="$HOME/.config/$name"
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            warn "backing up $dest -> ${dest}.bak"
            mv "$dest" "${dest}.bak"
        fi
        ln -sf "$src" "$dest"
        log "linked .config/$name"
    done
}

# ── base tools ────────────────────────────────────────────────────────────────
install_base() {
    log "installing base tools"
    pkg git curl wget jq tmux neovim \
        python python-pip python-pipx \
        go ruby \
        net-tools iproute2 whois bind \
        nmap tcpdump wireshark-qt wireshark-cli \
        proxychains-ng socat openbsd-netcat \
        openssl \
        unzip p7zip \
        ripgrep fd bat \
        xclip xdotool
}

# ── blackarch pentest tools ───────────────────────────────────────────────────
install_pentest() {
    log "installing pentest tools from blackarch + pacman"

    pkg sqlmap nikto whatweb wafw00f \
        hydra john hashcat \
        metasploit exploitdb \
        aircrack-ng \
        recon-ng theharvester \
        gobuster feroxbuster \
        wfuzz \
        seclists

    aur burpsuite \
        pwncat-cs \
        evil-winrm \
        wordlistctl \
        ffuf-bin \
        dalfox-bin \
        xsstrike
}

# ── go-based tools ────────────────────────────────────────────────────────────
install_go_tools() {
    log "installing go tools"
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"

    declare -A go_tools=(
        ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
        ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
        ["interactsh-client"]="github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
        ["notify"]="github.com/projectdiscovery/notify/cmd/notify@latest"
        ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["mapcidr"]="github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest"
        ["gau"]="github.com/lc/gau/v2/cmd/gau@latest"
        ["waybackurls"]="github.com/tomnomnom/waybackurls@latest"
        ["anew"]="github.com/tomnomnom/anew@latest"
        ["gf"]="github.com/tomnomnom/gf@latest"
        ["qsreplace"]="github.com/tomnomnom/qsreplace@latest"
        ["unfurl"]="github.com/tomnomnom/unfurl@latest"
        ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
        ["httprobe"]="github.com/tomnomnom/httprobe@latest"
        ["hakrawler"]="github.com/hakluke/hakrawler@latest"
        ["haklistgen"]="github.com/hakluke/haklistgen@latest"
        ["masscan"]="github.com/robertdavidgraham/masscan@latest"
    )

    for tool in "${!go_tools[@]}"; do
        log "  go install $tool"
        go install "${go_tools[$tool]}" 2>/dev/null || warn "  $tool failed, skipping"
    done

    # gf patterns
    if [[ ! -d ~/.gf ]]; then
        git clone https://github.com/1ndianl33t/Gf-Patterns ~/.gf
        log "gf patterns installed"
    fi

    # nuclei templates
    nuclei -update-templates 2>/dev/null || true
}

# ── python tools ──────────────────────────────────────────────────────────────
install_python_tools() {
    log "installing python tools"
    pipx install trufflehog 2>/dev/null || pip install --user trufflehog
    pipx install arjun       2>/dev/null || pip install --user arjun
    pipx install jwt_tool    2>/dev/null || pip install --user jwt_tool
    pipx install uro         2>/dev/null || pip install --user uro
    pip install --user \
        requests \
        httpx \
        beautifulsoup4 \
        lxml \
        censys \
        shodan \
        dnspython \
        paramiko \
        impacket \
        pwntools
}

# ── amass ─────────────────────────────────────────────────────────────────────
install_amass() {
    if command -v amass &>/dev/null; then
        log "amass already installed"
        return
    fi
    log "installing amass"
    local ver
    ver=$(curl -sf https://api.github.com/repos/owasp-amass/amass/releases/latest \
        | jq -r .tag_name)
    wget -q "https://github.com/owasp-amass/amass/releases/download/${ver}/amass_Linux_amd64.zip" \
        -O /tmp/amass.zip
    unzip -q /tmp/amass.zip -d /tmp/amass
    sudo mv /tmp/amass/amass_Linux_amd64/amass /usr/local/bin/
    rm -rf /tmp/amass /tmp/amass.zip
}

# ── wordlists ─────────────────────────────────────────────────────────────────
setup_wordlists() {
    log "setting up wordlists"
    sudo mkdir -p /usr/share/wordlists

    # rockyou
    if [[ ! -f /usr/share/wordlists/rockyou.txt ]]; then
        sudo gunzip -c /usr/share/wordlists/rockyou.txt.gz > /usr/share/wordlists/rockyou.txt \
            2>/dev/null || warn "rockyou.txt.gz not found -- install seclists first"
    fi

    # seclists symlink
    if [[ -d /usr/share/seclists && ! -L /usr/share/wordlists/seclists ]]; then
        sudo ln -sf /usr/share/seclists /usr/share/wordlists/seclists
    fi
}

# ── grub chicago95 theme ──────────────────────────────────────────────────────
setup_grub() {
    log "installing chicago95 grub theme"
    sudo mkdir -p /boot/grub/themes/chicago95
    sudo cp -r "$TOOLS_DIR/grub/chicago95/." /boot/grub/themes/chicago95/

    # set theme in grub config
    if grep -q '^GRUB_THEME=' /etc/default/grub; then
        sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/chicago95/theme.txt"|' /etc/default/grub
    else
        echo 'GRUB_THEME="/boot/grub/themes/chicago95/theme.txt"' | sudo tee -a /etc/default/grub
    fi

    # teal desktop color, no splash image
    sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' /etc/default/grub

    sudo grub-mkconfig -o /boot/grub/grub.cfg
    log "grub theme applied"
}

# ── plymouth chicago95 boot splash ────────────────────────────────────────────
setup_plymouth() {
    log "installing plymouth and chicago95 boot splash"

    pkg plymouth

    # install theme files
    sudo mkdir -p /usr/share/plymouth/themes/chicago95
    sudo cp "$TOOLS_DIR/plymouth/chicago95/chicago95.plymouth" \
            /usr/share/plymouth/themes/chicago95/
    sudo cp "$TOOLS_DIR/plymouth/chicago95/chicago95.script" \
            /usr/share/plymouth/themes/chicago95/

    # set as default
    sudo plymouth-set-default-theme chicago95

    # add plymouth to mkinitcpio hooks
    if ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
        sudo sed -i 's/\(HOOKS=.*\)udev/\1udev plymouth/' /etc/mkinitcpio.conf
    fi
    sudo mkinitcpio -P

    # add splash to grub kernel params if not already there
    sudo sed -i 's|quiet|quiet splash|' /etc/default/grub 2>/dev/null || true

    log "plymouth chicago95 splash installed"
}

# ── lightdm chicago95 login ───────────────────────────────────────────────────
setup_lightdm() {
    log "configuring lightdm with chicago95 greeter"

    pkg lightdm lightdm-gtk-greeter

    sudo cp "$TOOLS_DIR/lightdm/lightdm-gtk-greeter.conf" \
            /etc/lightdm/lightdm-gtk-greeter.conf

    # enable lightdm (artix openrc)
    if command -v rc-update &>/dev/null; then
        sudo rc-update add lightdm default
    # artix runit
    elif [[ -d /etc/runit/sv ]]; then
        sudo ln -sf /etc/runit/sv/lightdm /run/runit/service/ 2>/dev/null || true
    fi

    log "lightdm configured"
}

# ── shell PATH additions ───────────────────────────────────────────────────────
append_path() {
    local line='export PATH="$PATH:$HOME/go/bin:$HOME/.local/bin"'
    grep -qF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    log "chicago95-artix setup starting"

    setup_blackarch
    setup_yay
    install_base
    setup_chicago95
    setup_panel
    deploy_dots
    install_pentest
    install_go_tools
    install_python_tools
    install_amass
    setup_wordlists
    append_path
    setup_grub
    setup_plymouth
    setup_lightdm

    log "done. reboot to see grub + boot splash + login screen."
    log "run 'nuclei -update-templates' after first launch."
}

main "$@"
