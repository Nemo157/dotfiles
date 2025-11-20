{ lib, ... }:
let
  entryBefore = lib.hm.dag.entryBefore;
in {
  programs.ssh = {
    matchBlocks = {
      "*.infra.rust-lang.org" = {
        proxyJump = "bastion.infra.rust-lang.org";
        identityFile = "~/.ssh/id_ed25519.infra.rust-lang.org";
      };

      "bastion.infra.rust-lang.org" = entryBefore ["*.infra.rust-lang.org"] {
        user = "nemo157";
        proxyJump = "contabo";
      };

      "docsrs.infra.rust-lang.org" = {
        user = "ubuntu";
      };

      contabo = {
        user = "nemo157";
        port = 59127;
      };

      slate = {
        user = "overflow";
        port = 44247;
        setEnv = {
          TERM = "ansi";
        };
      };

      "victor.nemo157.com" = {
        port = 59127;
      };

      mithril = {
        forwardAgent = true;
      };
    };
  };
  home.file.".ssh/known_hosts".text = ''
    bastion.infra.rust-lang.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCPHGDab5kcdXMno2d4n9rETMfXuQVuyNkWqe6Jmhjps+zj6ezGLdQOSG7zxT3Va9wqZC6DfAQ89cOIl26TitQw=
    bastion.infra.rust-lang.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChdv/GN45AaqUQcJ0+RT6VvWoc5BzYnSYPaNlNaMwIW
    bastion.infra.rust-lang.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDMtyUz11Q/wsjLHTFPFUVV6O/mlkV/CFtxlnGJ/am3rgE1H+yNshA/WYH+nLfQRjpglVYjHXGvRCPkLmLyr0VdEJ+zYciMw1MFehA/4XDWkRqB9Fl+8zSqE616Y9SUZASp/fXH6pFn5HiArTFox/clGf9Si+EHszqRXH64hTq8fbs3DqrOOebN44lAQsCYkliRtrZOn0p5IUhMsR+WJXinWcfztWtShGzGkYcmN6sP8488NgJoZL3vDgBvCNjYSwBmWbDQj+lHcmObi3kC6zjGiYxYXVz9MLn1tKNJ6C/WgavyfRQW+DuQbHRkvb4cZpq9goEyyNzd0u5QjIfGYDMAK7r9ZGR7pdM1qHs9btVRX1xKWIN0OIxwpLyoN9fQCfY/CCERzjvi/BJNLPRUJ53+06c/+vhtnGDje3H0LsHjc1X3xu2RTvVmJO7FxUx/RG34fQ29Jd7TJbywCQsIBvYnaHKX2M2XxZv83HAV/CRCFIP7fT5jWG1hB3NnFU41jPc=

    contabo ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBap8/dDxDUVLcVn4U/bIGT44kw4Amm54kaRUwxdYEdZ
    mithril ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuIJQEiQuK0HxfPjk28NUkqJtzNQpv0nwJ55rQK4PKd
    slate ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgdPjQPwDdgtr0MgJL3OO886OtJdYoLe5rBRyXA31FY

    docsrs.infra.rust-lang.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBO+laPFbYTkh6pGR36X2oOmIDGHSlGSSpDLv+Lhtesz2qWNVuioSPpX9imaMssTrqUiWSRdzqAlatXiGXxKBz5A=
    docsrs.infra.rust-lang.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8l7FvHwVF6L2h3FnmRf/kXhka8+tyI/fg6/7oX9Fsw
    docsrs.infra.rust-lang.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsgWm2XvPYf1C3H6FrYUbX73tuKYMeO7QIiFNKVG0s4sv4QyF5waKYob3rXqPTKBTklTX48vt0I1v+FWjeTYiHEN/DTst/PFsjgxmtRdpH3DDZcuZJUDaPlkPDlaA8EyHvJakdaTE8dxURlOkNjBPSgFtwaTrKUlqP+N1r7QHTle8cZoFHRUBSEIhjaUc4nxZ5o0wrkn25Acb6zbbS4XJv+R8kCiOy/+z4bNKDx+xy9+ALGdWoiKi4/Z+QjxLCuaArBGwN4kDf3v132yFXQzeZcF5iGj/co7oo3nf6JEBSOQir7xiv6w8sszqI8Z3Y8eRvhQHDIdzykL5Raz6lH40T
  '';
}
