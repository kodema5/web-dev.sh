#!/bin/bash

WORK_DIR=$PWD
if [ "$OSTYPE" = "msys" ]; then
    WORK_DIR=$( echo "$PWD" | sed 's/^\///' | sed 's/\//\\/g' | sed 's/^./\0:/' )
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ $# = 0 ]; then

    echo "web-dev.sh [arg.*]"
    echo ""
    echo " docker-build     builds web-dev docker image"
    echo " docker-start     starts web-dev docker container"
    echo " docker-stop      stops web-dev docker container"

    echo " run [file.sql]   runs file.sql"
    echo " watch [file.sql] watches file.sql (requires https://nodemon.io)"
    echo " serve            serves web-dev.js (requires https://deno.land)"
    echo " psql * "
    echo " pg_dump * "
    echo " migra * "
    echo " bash * "

    echo ""
    echo "os: $OSTYPE"
    echo "cwd: $WORK_DIR"


elif [ "$1" = "docker-build" ]; then
    docker build -t web-dev dockerfile/.

elif [ "$1" = "docker-start" ]; then
    echo "docker-starting at $WORK_DIR"

    docker run --rm -d -p 5432:5432 \
        -v $WORK_DIR/.data/web-dev:/var/lib/postgresql/data \
        -v $WORK_DIR:/work \
        --name web-dev \
        -e POSTGRES_USER=web -e POSTGRES_PASSWORD=rei -e POSTGRES_DB=web \
        web-dev \
        -c shared_preload_libraries=pg_cron \
        -c cron.database_name=web

elif [ "$1" = "docker-stop" ]; then
    echo "docker-stop"
    docker stop web-dev

elif [ "$1" = "run" ]; then
    docker exec web-dev psql \
        -P pager=off -t --quiet -v -v ON_ERROR_STOP=1 \
        -U web -d web -f //test.sql -v test_file=//work//$2 \
        -v migration=f

elif [ "$1" = "watch" ]; then
    run="docker exec web-dev psql \
        -P pager=off -t --quiet -v -v ON_ERROR_STOP=1 \
        -U web -d web -f //test.sql -v test_file=//work//$2 \
        -v migration=f
    "
    nodemon -e sql --delay 1 -x "$run"

elif [ "$1" = "serve" ]; then
    deno run --allow-read --allow-net $SCRIPT_DIR/web-dev.js

elif [ "$1" = "psql" ]; then
    docker exec -it web-dev psql ${@:2}

elif [ "$1" = "pg_dump" ]; then
    docker exec web-dev pg_dump ${@:2}

elif [ "$1" = "pg_restore" ]; then
    docker exec web-dev pg_restore ${@:2}

elif [ "$1" = "createdb" ]; then
    docker exec web-dev createdb ${@:2}

elif [ "$1" = "dropdb" ]; then
    docker exec web-dev dropdb ${@:2}

elif [ "$1" = "migra" ]; then
#
# https://databaseci.com/docs/migra/quickstart
#
# pg_dump --no-owner --no-privileges --schema-only -d postgresql://production -f schema.dump.sql
# createdb existing
# psql -d postgresql:///existing -f schema.dump.sql
# migra --unsafe --schema <schema_name> postgresql:///existing postgresql:///database_with_new_schema > migration_<schema_name>_script.sql
# dropdb existing
# psql -d postgresql://production -1 -f migration_script.sql
#
    docker exec web-dev migra ${@:2}

elif [ "$1" = "bash" ]; then
    docker exec -it web-dev bash ${@:2}

fi

