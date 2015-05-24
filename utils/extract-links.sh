#!/bin/sh
# use: cat pkg/* | utils/extract-links.sh
 
grep -E '^http://|^https://|^ftp://'
