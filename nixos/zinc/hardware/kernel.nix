{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod"
      ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModprobeConfig = ''
      options hid_apple swap_opt_cmd=1
    '';
  };
}
