{ pkgs-final, ... }:
{ pname, version, ...  } @ args:
pkgs-final.fetchzip ({
  url = "https://crates.io/api/v1/crates/${pname}/${version}/download";
  name = "${pname}-${version}.crate";
  stripRoot = true;
  extension = ".tar.gz";
} // removeAttrs args [ "pname" "version" ])
