#!/bin/bash
set -e

echoerr() { echo "$@" 1>&2; }

# Split out host and port from DB_HOST env variable
IFS=":" read -r DB_HOST_NAME DB_PORT <<< "$DB_HOST"
DB_PORT=${DB_PORT:-3306}

if [ ! -f ".env" ]; then
  if [[ "${DB_HOST}" ]]; then
  cat > ".env" <<EOF
      # Environment
      APP_ENV=production
      APP_DEBUG=${APP_DEBUG:-false}
      APP_KEY=${APP_KEY:-SomeRandomStringWith32Characters}

      # The below url has to be set if using social auth options
      # or if you are not using BookStack at the root path of your domain.
      APP_URL=${APP_URL:-null}

      # Database details
      DB_HOST=${DB_HOST:-localhost}
      DB_DATABASE=${DB_DATABASE:-bookstack}
      DB_USERNAME=${DB_USERNAME:-bookstack}
      DB_PASSWORD=${DB_PASSWORD:-password}

      # Cache and session
      CACHE_DRIVER=file
      SESSION_DRIVER=file
      # If using Memcached, comment the above and uncomment these
      #CACHE_DRIVER=memcached
      #SESSION_DRIVER=memcached
      QUEUE_DRIVER=sync

      # Memcached settings
      # If using a UNIX socket path for the host, set the port to 0
      # This follows the following format: HOST:PORT:WEIGHT
      # For multiple servers separate with a comma
      MEMCACHED_SERVERS=127.0.0.1:11211:100

      # Storage
      STORAGE_TYPE=${STORAGE_TYPE:-local}
      # Amazon S3 Config
      STORAGE_S3_KEY=${STORAGE_S3_KEY:-false}
      STORAGE_S3_SECRET=${STORAGE_S3_SECRET:-false}
      STORAGE_S3_REGION=${STORAGE_S3_REGION:-false}
      STORAGE_S3_BUCKET=${STORAGE_S3_BUCKET:-false}
      # Storage URL
      # Used to prefix image urls for when using custom domains/cdns
      STORAGE_URL=${STORAGE_URL:-false}

      # General auth
      AUTH_METHOD=${AUTH_METHOD:-standard}

      # Social Authentication information. Defaults as off.
      GITHUB_APP_ID=${GITHUB_APP_ID:-false}
      GITHUB_APP_SECRET=${GITHUB_APP_SECRET:-false}
      GOOGLE_APP_ID=${GOOGLE_APP_ID:-false}
      GOOGLE_APP_SECRET=${GOOGLE_APP_SECRET:-false}

      # External services such as Gravatar
      DISABLE_EXTERNAL_SERVICES=${DISABLE_EXTERNAL_SERVICES:-false}

      # LDAP Settings
      LDAP_SERVER=${LDAP_SERVER:-false}
      LDAP_BASE_DN=${LDAP_BASE_DN:-false}
      LDAP_DN=${LDAP_DN:-false}
      LDAP_PASS=${LDAP_PASS:-false}
      LDAP_USER_FILTER=${LDAP_USER_FILTER:-false}
      LDAP_VERSION=${LDAP_VERSION:-false}
      LDAP_ID_ATTRIBUTE=${LDAP_ID_ATTRIBUTE:-false}
      LDAP_TLS_INSECURE=${LDAP_TLS_INSECURE:-false}
      LDAP_DISPLAY_NAME_ATTRIBUTE=${LDAP_DISPLAY_NAME_ATTRIBUTE:-false}

      # SAML2 Settings; AUTH_MODE=saml2
      AUTH_AUTO_INITIATE=${AUTH_AUTO_INITIATE:-false}
      SAML2_NAME=${SAML2_NAME:-null}
      SAML2_EMAIL_ATTRIBUTE=${SAML2_EMAIL_ATTRIBUTE:-null}
      SAML2_EXTERNAL_ID_ATTRIBUTE=${SAML2_EXTERNAL_ID_ATTRIBUTE:-null}
      SAML2_USER_TO_GROUPS=${SAML2_USER_TO_GROUPS:-false}
      SAML2_GROUP_ATTRIBUTE=${SAML2_GROUP_ATTRIBUTE:-null}
      SAML2_DISPLAY_NAME_ATTRIBUTES=${SAML2_DISPLAY_NAME_ATTRIBUTES:-null}
      SAML2_IDP_ENTITYID=${SAML2_IDP_ENTITYID:-null}
      SAML2_AUTOLOAD_METADATA=${SAML2_AUTOLOAD_METADATA:-false}
      SAML2_IDP_SSO=${SAML2_IDP_SSO:-null}
      SAML2_IDP_SLO=${SAML2_IDP_SLO:-null}
      SAML2_IDP_x509=${SAML2_IDP_x509:-null}
      SAML2_IDP_AUTHNCONTEXT=${SAML2_IDP_AUTHNCONTEXT:-false}
      SAML2_SP_x509=${SAML2_SP_x509:-null}
      SAML2_SP_x509_KEY=${SAML2_SP_x509_KEY:-null}
      SAML2_DUMP_USER_DETAILS=${SAML2_DUMP_USER_DETAILS:-false}
      SAML2_ONELOGIN_OVERRIDES=${SAML2_ONELOGIN_OVERRIDES:-null}
      SAML2_REMOVE_FROM_GROUPS=${SAML2_REMOVE_FROM_GROUPS:-false}

      # Mail settings
      MAIL_DRIVER=${MAIL_DRIVER:-smtp}
      MAIL_HOST=${MAIL_HOST:-localhost}
      MAIL_PORT=${MAIL_PORT:-1025}
      MAIL_USERNAME=${MAIL_USERNAME:-null}
      MAIL_PASSWORD=${MAIL_PASSWORD:-null}
      MAIL_ENCRYPTION=${MAIL_ENCRYPTION:-null}
      # URL used for social login redirects, NO TRAILING SLASH
EOF
    else
        echo >&2 'error: missing DB_HOST environment variable'
        exit 1
    fi
fi

echoerr "wait-for-db: waiting for ${DB_HOST_NAME}:${DB_PORT}"

timeout 15 bash <<EOT
while ! (echo > /dev/tcp/${DB_HOST_NAME}/${DB_PORT}) >/dev/null 2>&1;
    do sleep 1;
done;
EOT
RESULT=$?

if [ $RESULT -eq 0 ]; then
  # sleep another second for so that we don't get a "the database system is starting up" error
  sleep 1
  echoerr "wait-for-db: done"
else
  echoerr "wait-for-db: timeout out after 15 seconds waiting for ${DB_HOST_NAME}:${DB_PORT}"
fi

echo "Generating Key..."
php artisan key:generate --show

echo "Starting Migration..."
php artisan migrate --force

echo "Clearing caches..."
php artisan cache:clear
php artisan view:clear

trap "echo Catching SIGWINCH apache error and perventing it." SIGWINCH
exec apache2-foreground
