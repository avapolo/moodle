#!/usr/bin/env bash

source /etc/profile
set -Eeo pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

#usage: sql HOST USER PASS args
sql() {
  export PGPASSWORD="$3"
  psql -v ON_ERROR_STOP=1 -h "$1" -U "$2" "${@:4}"
  unset PGPASSWORD
}

peer1SQL() {
  sql "$DB_REPLICATION_PEER1" "$DB_USER" "$DB_PASS" "$@"
}

peer2SQL() {
  sql "$DB_REPLICATION_PEER2" "$DB_USER" "$DB_PASS" "$@"
}

file_env 'ADMIN_PASS' 'Admin@123'
file_env 'APP_PATH' '/app'
file_env 'MOODLEDATA_PATH' "$APP_PATH/moodledata"
file_env 'MOODLE_PATH' "$APP_PATH/public"

is_initialized() {
  if [[ -f "$MOODLEDATA_PATH/initialized" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

set_as_initialized() {
  touch "$MOODLEDATA_PATH/initialized"
}

create_moodledata() {
  echo "Creating moodledata on path: $MOODLEDATA_PATH"
  mkdir -p "$MOODLEDATA_PATH"
  chown -R apache:apache "$MOODLEDATA_PATH"
}

install_database() {
  echo "Running database migration."
  php "$MOODLE_PATH/admin/cli/install_database.php" --lang=pt_br --adminuser=admin --adminpass="$ADMIN_PASS" --adminemail=admin@avapolos.com --fullname='Moodle AVAPolos' --shortname='Mdl AVA' --agree-license
  php "$MOODLE_PATH/admin/cli/upgrade.php" --non-interactive
}

create_filesystem_repository() {
  echo "Creating filesystem repository."
  mkdir -p "$MOODLEDATA_PATH/repository/avapolos"
  php "$MOODLE_PATH/admin/avapolos/create_repo.php"
}

fix_db_sequences() {
  echo "Fixing database sequences."
  php "$MOODLE_PATH/admin/avapolos/par.php"
  php "$MOODLE_PATH/admin/avapolos/impar.php"
}

purge_caches() {
  echo "Purging caches."
  php "$MOODLE_PATH/admin/cli/purge_caches.php"
}

_main() {

  if [[ "$(is_initialized)" == "false" ]]; then
    echo
    echo "Initializing moodle installation."
    echo

    create_moodledata
    install_database
    create_filesystem_repository
    fix_db_sequences
    purge_caches
    set_as_initialized

    echo
    echo "Moodle initialization was successful, starting apache."
    echo
  else
    echo
    echo "Moodle is already initialized, starting apache."
    echo
  fi

  exec "$@"

}

_main "$@"


#Email change confirmation disable.
#execSqlOnMoodleDB db_moodle_ies "UPDATE mdl_config SET VALUE=0 WHERE id=243;"

#Mobile app enable.
# execSqlOnMoodleDB db_moodle_ies "UPDATE mdl_config SET VALUE=1 WHERE id=484;"
# execSqlOnMoodleDB db_moodle_ies "UPDATE mdl_external_services SET enabled=1 WHERE shortname LIKE '%moodle_mobile_app%';"

# execSqlOnMoodleDB db_moodle_ies "SELECT * FROM mdl_config WHERE id=243 OR id=484;"
# execSqlOnMoodleDB db_moodle_ies "SELECT * FROM mdl_external_services WHERE shortname LIKE '%mobile%';"





# echo "Checando instalação do Moodle na IES."
# execSqlOnMoodleDB db_moodle_ies "SELECT * from mdl_user;"

# echo "Checando instalação do Moodle no POLO."
# execSqlOnMoodleDB db_moodle_polo "SELECT * from mdl_user;"
