#!/bin/bash

check_connectivity() {
    curl -s --connect-timeout 5 https://omarchy.org/ > /dev/null
}

INTERNET=`check_connectivity`
while ! $INTERNET; do
    impala
    INTERNET=`check_connectivity`
done