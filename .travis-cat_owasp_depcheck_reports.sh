#!/bin/bash
set -e # exit as soon as command executed exits != 0
if [[ $TRAVIS_BRANCH == 'master' || $TRAVIS_BRANCH == 'develop' ]]; then
  echo "Executing owasp dependency check on branch $TRAVIS_BRANCH"
  ./gradlew dependencyCheckAnalyze
  echo "Listing of owasp dependency check reports (csv) if present:"
  echo "---------------------------------------------- org.testeditor.web.backend.testexecution"
  [ -f build/reports/dependency-check-report.csv ] && cat build/reports/dependency-check-report.csv
else
  echo "No owasp dependency check on branch $TRAVIS_BRANCH"
fi
