{ lib, ... }:
let
  entryBefore = lib.hm.dag.entryBefore;
in {
  programs.ssh = {
    enable = true;

    controlPath = "~/.ssh/control/%r@%n:%p";
    controlMaster = "auto";
    controlPersist = "1m";
    userKnownHostsFile = "~/.ssh/known_hosts.new ~/.ssh/known_hosts";

    matchBlocks = {
      "*" = {
        extraOptions = {
          AddKeysToAgent = "1d";
          StrictHostKeyChecking = "ask";
          UpdateHostKeys = "ask";
        };
      };

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

      mithril = {
        forwardAgent = true;
      };
    };
  };

  home.file.".ssh/control/.keep".text = "";

  home.file.".ssh/known_hosts".text = ''
    bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw==

    bastion.infra.rust-lang.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCPHGDab5kcdXMno2d4n9rETMfXuQVuyNkWqe6Jmhjps+zj6ezGLdQOSG7zxT3Va9wqZC6DfAQ89cOIl26TitQw=
    bastion.infra.rust-lang.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChdv/GN45AaqUQcJ0+RT6VvWoc5BzYnSYPaNlNaMwIW
    bastion.infra.rust-lang.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDMtyUz11Q/wsjLHTFPFUVV6O/mlkV/CFtxlnGJ/am3rgE1H+yNshA/WYH+nLfQRjpglVYjHXGvRCPkLmLyr0VdEJ+zYciMw1MFehA/4XDWkRqB9Fl+8zSqE616Y9SUZASp/fXH6pFn5HiArTFox/clGf9Si+EHszqRXH64hTq8fbs3DqrOOebN44lAQsCYkliRtrZOn0p5IUhMsR+WJXinWcfztWtShGzGkYcmN6sP8488NgJoZL3vDgBvCNjYSwBmWbDQj+lHcmObi3kC6zjGiYxYXVz9MLn1tKNJ6C/WgavyfRQW+DuQbHRkvb4cZpq9goEyyNzd0u5QjIfGYDMAK7r9ZGR7pdM1qHs9btVRX1xKWIN0OIxwpLyoN9fQCfY/CCERzjvi/BJNLPRUJ53+06c/+vhtnGDje3H0LsHjc1X3xu2RTvVmJO7FxUx/RG34fQ29Jd7TJbywCQsIBvYnaHKX2M2XxZv83HAV/CRCFIP7fT5jWG1hB3NnFU41jPc=

    contabo ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBap8/dDxDUVLcVn4U/bIGT44kw4Amm54kaRUwxdYEdZ

    docsrs.infra.rust-lang.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBO+laPFbYTkh6pGR36X2oOmIDGHSlGSSpDLv+Lhtesz2qWNVuioSPpX9imaMssTrqUiWSRdzqAlatXiGXxKBz5A=
    docsrs.infra.rust-lang.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8l7FvHwVF6L2h3FnmRf/kXhka8+tyI/fg6/7oX9Fsw
    docsrs.infra.rust-lang.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsgWm2XvPYf1C3H6FrYUbX73tuKYMeO7QIiFNKVG0s4sv4QyF5waKYob3rXqPTKBTklTX48vt0I1v+FWjeTYiHEN/DTst/PFsjgxmtRdpH3DDZcuZJUDaPlkPDlaA8EyHvJakdaTE8dxURlOkNjBPSgFtwaTrKUlqP+N1r7QHTle8cZoFHRUBSEIhjaUc4nxZ5o0wrkn25Acb6zbbS4XJv+R8kCiOy/+z4bNKDx+xy9+ALGdWoiKi4/Z+QjxLCuaArBGwN4kDf3v132yFXQzeZcF5iGj/co7oo3nf6JEBSOQir7xiv6w8sszqI8Z3Y8eRvhQHDIdzykL5Raz6lH40T

    @revoked gist.github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
    gist.github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    gist.github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    gist.github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=

    @revoked github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=

    gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
  '';
}
