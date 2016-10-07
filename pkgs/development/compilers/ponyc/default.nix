{stdenv, fetchFromGitHub, llvm, makeWrapper, pcre2, coreutils, which, libressl }:

stdenv.mkDerivation {
  name = "ponyc-0.4.0";

  src = fetchFromGitHub {
    owner = "ponylang";
    repo = "ponyc";
    rev = "01579a1557e413468388f86f395e5d5d8b8e4915";
    sha256 = "0ljfs8z3v13bz8k6rdww726rgh07752czbwp60kj3cjjxy6lkfg5";
  };

  buildInputs = [ llvm makeWrapper which ];

  # Disable problematic networking tests
  patches = [ ./disable-tests.patch ];

  preBuild = ''
    # Fix tests
    substituteInPlace packages/process/_test.pony \
        --replace "/bin" "${coreutils}/bin"

    # Fix llvm-ar check for darwin
    substituteInPlace Makefile \
        --replace "llvm-ar-3.8" "llvm-ar"

    # Remove impure system refs
    substituteInPlace src/libponyc/pkg/package.c \
        --replace "/usr/local/lib" ""
    substituteInPlace src/libponyc/pkg/package.c \
        --replace "/opt/local/lib" ""

    for file in `grep -irl '/usr/local/opt/libressl/lib' ./*`; do
      substituteInPlace $file  --replace '/usr/local/opt/libressl/lib' "${stdenv.lib.getLib libressl}/lib"
    done

    # Fix ponypath issue
    substituteInPlace Makefile \
        --replace "PONYPATH=." "PONYPATH=.:\$(PONYPATH)"

    export LLVM_CONFIG=${llvm}/bin/llvm-config
  '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
    export LTO_PLUGIN=`find ${stdenv.cc.cc}/ -name liblto_plugin.so`
  '';

  makeFlags = [ "config=release" ] ++ stdenv.lib.optionals stdenv.isDarwin [ "bits=64" ];

  enableParallelBuilding = true;

  doCheck = true;

  checkTarget = "test-ci";

  preCheck = ''
    export PONYPATH="$out/lib:${stdenv.lib.makeLibraryPath [ pcre2 libressl ]}"
  '';

  installPhase = ''
    make config=release prefix=$out '' + stdenv.lib.optionalString stdenv.isDarwin ''bits=64 '' + '' install
    mv $out/bin/ponyc $out/bin/ponyc.wrapped
    makeWrapper $out/bin/ponyc.wrapped $out/bin/ponyc \
      --prefix PONYPATH : "$out/lib" \
      --prefix PONYPATH : "${stdenv.lib.getLib pcre2}/lib" \
      --prefix PONYPATH : "${stdenv.lib.getLib libressl}/lib"
  '';

  # Stripping breaks linking for ponyc
  dontStrip = true;

  meta = {
    description = "Pony is an Object-oriented, actor-model, capabilities-secure, high performance programming language";
    homepage = http://www.ponylang.org;
    license = stdenv.lib.licenses.bsd2;
    maintainers = [ stdenv.lib.maintainers.doublec ];
    platforms = stdenv.lib.platforms.unix;
  };
}
