/*

  # Run the server in rescue mode and SSH in.

  # Run https://github.com/nix-community/nixos-images#kexec-tarballs

  # You can get a basic system via:

  # curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | tar -xzf- -C /root
  # /root/kexec/run

  # SSH in again, and you can start setup.

  # Create a new MBR partition table
  parted /dev/nvme0n1 --script mklabel msdos

  # Create a 512MB boot partition with ext4
  parted /dev/nvme0n1 --script mkpart primary ext4 1MiB 513MiB
  parted /dev/nvme0n1 --script set 1 boot on
  mkfs.ext4 -L boot /dev/nvme0n1p1

  # Create an 8GB swap partition
  parted /dev/nvme0n1 --script mkpart primary linux-swap 513MiB 8577MiB
  mkswap -L swap /dev/nvme0n1p2
  swapon /dev/nvme0n1p2

  # Create a 1GB partition for secrets / config.
  parted /dev/nvme0n1 --script mkpart primary ext4 8577MiB 9577MiB
  mkfs.ext4 -L secrets /dev/nvme0n1p3
  
  # Create a root partition with the remaining space
  parted /dev/nvme0n1 --script mkpart primary ext4 9577MiB 100%
  mkfs.ext4 -L nixos /dev/nvme0n1p3

  # Mount the partitions to /mnt and /mnt/boot.
  mount /dev/disk/by-label/nixos /mnt
  mkdir -p /mnt/boot
  mount /dev/disk/by-label/boot /mnt/boot

  # Install.
  sudo nixos-install --flake github:a-h/nixos#hetzner-dedicated-x86_64

*/
{ pkgs, config, adrianSSHKey, rootSSHKey, ... }:
{
  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  # Virtualisation configuration.
  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
  programs.virt-manager.enable = true;
  boot.kernelModules = [ "kvm-amd" "kvm-intel" ];
  # Enable this system to cross-compile for aarch64-linux using kvm.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Create a symlink from /bin/true to the Nix-managed true binary.
  environment.etc."bin/true".source = "${pkgs.coreutils}/bin/true";
  # CIS 1.1.1.1.a Ensure mounting of cramfs filesystems is disabled
  environment.etc."modprobe.d/cramfs.conf".text = ''
    install cramfs /bin/true
  '';
  # CIS 1.1.1.2.a Ensure mounting of freevxfs filesystems is disabled
  environment.etc."modprobe.d/freevxfs.conf".text = ''
    install freevxfs /bin/true
  '';
  # CIS 1.1.1.3.a Ensure mounting of jffs2 filesystems is disabled
  environment.etc."modprobe.d/jffs2.conf".text = ''
    install jffs2 /bin/true
  '';
  # CIS 1.1.1.4.a Ensure mounting of hfs filesystems is disabled
  environment.etc."modprobe.d/hfs.conf".text = ''
    install hfs /bin/true
  '';
  # CIS 1.1.1.5.a Ensure mounting of hfsplus filesystems is disabled
  environment.etc."modprobe.d/hfsplus.conf".text = ''
    install hfsplus /bin/true
  '';
  # CIS 1.1.1.6.a Ensure mounting of squashfs filesystems is disabled
  environment.etc."modprobe.d/squashfs.conf".text = ''
    install squashfs /bin/true
  '';
  # CIS 1.1.1.7.a Ensure mounting of udf filesystems is disabled
  environment.etc."modprobe.d/udf.conf".text = ''
    install udf /bin/true
  '';
  # CIS 1.1.1.8.a Ensure mounting of FAT filesystems is disabled
  environment.etc."modprobe.d/fat.conf".text = ''
    install fat /bin/true
  '';

  environment.systemPackages = [
    pkgs.git
    pkgs.nebula
    pkgs.tmux
    pkgs.unzip
    pkgs.vim
    pkgs.wget
    pkgs.zip
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "ext4";
  };
  fileSystems."/mnt/secrets" = {
    device = "/dev/disk/by-label/secrets";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    options = [ "nofail" ];
  };
  # CIS 1.1.2.a - Ensure /tmp is configured
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "rw" "nodev" "relatime" ];
  };
  swapDevices = [
    {
      device = "/dev/disk/by-label/swap";
    }
  ];

  documentation.nixos.enable = false;
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "us";
  nix.settings.trusted-users = [ "adrian" "@wheel" ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "ext4" ];

  boot.kernel.sysctl = {
    # CIS 3.2.9.a - Disable IPv6 Router Advertisements
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;
  };

  users.users = {
    root.hashedPassword = "!"; # Disable root login
    adrian = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" ];
      openssh.authorizedKeys.keys = [
        adrianSSHKey
        rootSSHKey
      ];
    };
  };

  # CIS 1.5.1.a - Ensure core dumps are restricted
  systemd.coredump.enable = false;

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    # CIS 5.2 SSH Server Configuration
    extraConfig = ''
      Protocol 2
      MaxAuthTries 4
      PermitEmptyPasswords no
      PermitUserEnvironment no
      MaxSessions 4
      LoginGraceTime 60
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [
      22 # SSH
      80 # For ACME challenges
      443 # HTTPS for cache.adrianhesketh.com
    ];
  };

  services.minio = {
    enable = true;
    configDir = "/mnt/secrets/minio";
    dataDir = [ "/mnt/storage/minio" ];
    rootCredentialsFile = "/mnt/secrets/minio/minio-root-credentials";
    listenAddress = "localhost:9000";
    consoleAddress = "localhost:9001";
  };

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # When adding a new host, don't force SSL until the certificate has been generated.
    # Enable web sockets for the Minio console.
    virtualHosts."minio-console.adrianhesketh.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${config.services.minio.consoleAddress}";
        proxyWebsockets = true;
        # Allow large uploads to Minio.
        extraConfig = ''
          client_max_body_size 0;
        '';
      };
    };
    virtualHosts."minio.adrianhesketh.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${config.services.minio.listenAddress}";
        # Allow large uploads to Minio.
        extraConfig = ''
          client_max_body_size 0;
        '';
      };
    };
    virtualHosts."_" = {
      locations."/" = {
        proxyPass = "http://localhost:9090";
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    certs = {
      "minio-console.adrianhesketh.com".email = "acme@adrianhesketh.com";
      "minio.adrianhesketh.com".email = "acme@adrianhesketh.com";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
