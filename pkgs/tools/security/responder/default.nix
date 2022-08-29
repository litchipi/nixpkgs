{
  fetchFromGitHub,
  python310,
  stdenv,
  lib,
  writeShellScript,
}:
let
  pythonpkg = python310.withPackages (p: [
    p.netifaces
  ]);
in
stdenv.mkDerivation rec {
  pname = "responder";
  version = "3.1.3.0";

  src = fetchFromGitHub {
    owner = "lgandx";
    repo = "Responder";
    rev = "v${version}";
    sha256 = "sha256-ZnWUkV+9fn08Ze4468wSUtldABrmn+88N2Axc+Mip2A=";
  };

  installPhase = let
    start_python_script = name: script:
      writeShellScript "responder_${name}" "${pythonpkg}/bin/python ${script}";
  in ''
    mkdir -p $out/bin
    cp ${start_python_script "main" "${src}/Responder.py"} $out/bin/Responder
    cp ${start_python_script "tool_icmp_redirect" "${src}/tools/Icmp-Redirect.py"} \
      $out/bin/Responder_IcmpRedirect
    cp ${start_python_script "tool_dhcp" "${src}/tools/DHCP.py"} $out/bin/Responder_DHCP
  '';

  meta = with lib; {
    description = ''
      LLMNR, NBT-NS and MDNS poisoner with built-in HTTP/SMB/MSSQL/FTP/LDAP
      rogue authentication server supporting NTLMv1/NTLMv2/LMv2,
      Extended Security NTLMSSP and Basic HTTP authentication.
    '';
    homepage = "https://github.com/lgandx/Responder";
    license = with licenses; [ gpl3 ];
    maintainers = with maintainers; [ litchipi ];
  };
}
