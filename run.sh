#!/bin/bash

cd $WORK_DIR

export REPO_ROOT="$WORK_DIR/repo"

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

# Additional options to be passed to the JVM can be provided via the
# TE_JAVA_OPTIONS environment variable
export JAVA_TOOL_OPTIONS="${TE_JAVA_OPTIONS} -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStore=${WORK_DIR}/testeditor.certs"
keytool -importkeystore -srckeystore $JAVA_HOME/lib/security/cacerts -destkeystore ${WORK_DIR}/testeditor.certs -srcstorepass changeit -deststorepass changeit -noprompt
if [ "$PROXY_CERT" != "" ]; then
  echo "importing certificate into java certificate store"
  keytool -importcert -file $PROXY_CERT -keystore ${WORK_DIR}/testeditor.certs -storepass changeit -noprompt -trustcacerts
fi

export GRADLE_USER_HOME=$WORK_DIR/.gradle
GRADLE_PROPS_TARGET_FILE=$GRADLE_USER_HOME/gradle.properties
if [ "$GRADLE_PROPS_CONTENT" != "" ]; then
  echo "using gradle properties with content passed through env"
  mkdir -p `dirname $GRADLE_PROPS_TARGET_FILE`
  echo "$GRADLE_PROPS_CONTENT" > $GRADLE_PROPS_TARGET_FILE
elif [ "$GRADLE_PROPS" != "" ]; then
  echo "using gradle properties from file location passed through env"
  mkdir -p `dirname $GRADLE_PROPS_TARGET_FILE`
  cp ${GRADLE_PROPS} ${GRADLE_PROPS_TARGET_FILE}
fi

if [ -f $GRADLE_PROPS_TARGET_FILE -a "$http_proxyUser" != "" ]; then
  echo "configuring gradle properties with proxy credentials"
  sed -i "s|%http_proxyUser%|$http_proxyUser|g" ${GRADLE_PROPS_TARGET_FILE}
  sed -i "s|%http_proxyPassword%|$http_proxyPassword|g" ${GRADLE_PROPS_TARGET_FILE}
fi

if [ "$TIMEZONE" != "" ]; then
  echo "configuring timezone"
  export TZ="/usr/share/zoneinfo/$TIMEZONE"
fi

if [ "$GIT_PRIVATE_KEY" != "" ]; then
  echo "configuring private key for repo access"
  KEY_LOCATION=${WORK_DIR}/ssh-keys/ssh-privatekey
  mkdir -p `dirname $KEY_LOCATION`
  echo "$GIT_PRIVATE_KEY" > $KEY_LOCATION
  chmod 600 $KEY_LOCATION
  sha1sum $KEY_LOCATION
fi

KNOWN_HOSTS_FILE=${WORK_DIR}/ssh-keys/known_hosts
mkdir -p ${WORK_DIR}/ssh-keys
if [ "$KNOWN_HOSTS" != "" ]; then
  echo "copying passed known_hosts file from $KNOWN_HOSTS"
  cp $KNOWN_HOSTS $KNOWN_HOSTS_FILE
else
  touch $KNOWN_HOSTS_FILE
fi

if [ "$KNOWN_HOSTS_CONTENT" != "" ]; then
  echo "configuring known hosts"
  echo "$KNOWN_HOSTS_CONTENT" >> $KNOWN_HOSTS_FILE
fi

if [ "$ADD_KNOWN_HOSTS_DOMAIN" != "" ]; then
  echo "configuring additional known host domains: $ADD_KNOWN_HOSTS_DOMAIN"
  DOMAIN="${ADD_KNOWN_HOSTS_DOMAIN%:*}"
  PORT="${ADD_KNOWN_HOSTS_DOMAIN/[a-z]*:/}"
  echo "using domain: $DOMAIN port: $PORT"
  ssh-keyscan -p $PORT $DOMAIN >> $KNOWN_HOSTS_FILE
fi

cat $KNOWN_HOSTS_FILE | sort | uniq > TEMP
mv TEMP $KNOWN_HOSTS_FILE
echo "using known hosts:"
cat $KNOWN_HOSTS_FILE

cp $PROG_DIR/config.template.yml $WORK_DIR/config.yml
sed -i "s|%TARGET_REPO%|$TARGET_REPO|g" $WORK_DIR/config.yml
sed -i "s|%REPO_ROOT%|$REPO_ROOT|g" $WORK_DIR/config.yml
sed -i "s|%BRANCH_NAME%|$BRANCH_NAME|g" $WORK_DIR/config.yml
sed -i "s|%API_TOKEN_SECRET%|$API_TOKEN_SECRET|g" $WORK_DIR/config.yml
sed -i "s|%KEY_LOCATION%|$KEY_LOCATION|g" $WORK_DIR/config.yml
sed -i "s|%KNOWN_HOSTS%|$KNOWN_HOSTS_FILE|g" $WORK_DIR/config.yml

export HOME=/opt/testeditor

export DISPLAY=:99.0

cd $WORK_DIR
exec $PROG_DIR/bin/test-editor-testexecution server $WORK_DIR/config.yml
