{ lib
, callPackage
, fetchFromGitHub
, makeWrapper
, python3
, writeShellScript
}:

let
  version = "1.1.0";
  src = fetchFromGitHub {
    owner = "mealie-recipes";
    repo = "mealie";
    rev = "v${version}";
    sha256 = "sha256-k2jMGJ6bdhkXootWl9cEdevRrGfggmHbkJZHZmhNLTM=";
  };

  frontend = callPackage (import ./mealie-frontend.nix src version) { };

  python = python3.override {
    packageOverrides = self: super: {
      pydantic = self.pydantic_1;
    };
  };

  # TODO  Add crfpp in runtime dependencies for ingredient quantities NLP

in python.pkgs.buildPythonPackage rec {
  pname = "mealie";
  inherit version src;
  pyproject = true;

  patches = [
    # See https://github.com/mealie-recipes/mealie/pull/3102
    # Replace hardcoded paths in code with environment variables (meant for inside Docker only)
    # So we can configure easily where the data is stored on the server
    ./mealie_init_db.patch
    ./mealie_logger.patch
  ];

  nativeBuildInputs = [
    python.pkgs.poetry-core
    python.pkgs.pythonRelaxDepsHook
    makeWrapper
  ];

  dontWrapPythonPrograms = true;

  pythonRelaxDeps = true;

  propagatedBuildInputs = with python.pkgs; [
    aiofiles
    alembic
    aniso8601
    appdirs
    apprise
    bcrypt
    extruct
    fastapi
    gunicorn
    html2text
    httpx
    jinja2
    lxml
    orjson
    passlib
    pillow
    psycopg2
    pyhumps
    pytesseract
    python-dotenv
    python-jose
    python-ldap
    python-multipart
    python-slugify
    pyyaml
    rapidfuzz
    recipe-scrapers
    sqlalchemy
    tzdata
    uvicorn
  ];

  postInstall = let
    start_script = writeShellScript "start-mealie" ''
      ${lib.getExe python.pkgs.gunicorn} "$@" -k uvicorn.workers.UvicornWorker mealie.app:app;
    '';
    init_db = writeShellScript "init-mealie-db" ''
      ${python.interpreter} $OUT/${python.sitePackages}/mealie/db/init_db.py
    '';
  in ''
    mkdir -p $out/config $out/bin $out/libexec
    rm -f $out/bin/*

    substitute ${src}/alembic.ini $out/config/alembic.ini \
      --replace-fail 'script_location = alembic' 'script_location = ${src}/alembic'

    makeWrapper ${start_script} $out/bin/mealie \
      --set PYTHONPATH "$out/${python.sitePackages}:${python.pkgs.makePythonPath propagatedBuildInputs}" \
      --set STATIC_FILES ${frontend}

    makeWrapper ${init_db} $out/libexec/init_db \
      --set PYTHONPATH "$out/${python.sitePackages}:${python.pkgs.makePythonPath propagatedBuildInputs}" \
      --set OUT "$out"
  '';

  checkInputs = with python.pkgs; [
    pytestCheckHook
  ];

  meta = with lib; {
    description = "A self hosted recipe manager and meal planner";
    longDescription = ''
      Mealie is a self hosted recipe manager and meal planner with a RestAPI backend and a reactive frontend
      application built in NuxtJS for a pleasant user experience for the whole family. Easily add recipes into your
      database by providing the URL and Mealie will automatically import the relevant data or add a family recipe with
      the UI editor.
    '';
    homepage = "https://mealie.io";
    changelog = "https://github.com/mealie-recipes/mealie/releases/tag/${src.rev}";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ litchipi ];
    mainProgram = "mealie";
  };
}
