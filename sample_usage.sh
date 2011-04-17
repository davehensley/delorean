#!/bin/bash
# Delete the old dailies (over 2 weeks old)
find /backup/directory/daily/* -maxdepth 0 -ctime +14 -print | xargs rm -rf

# And also delete the old weeklies (over 2 months old)
find /backup/directory/weekly/* -maxdepth 0 -ctime +60 -print | xargs rm -rf

# Run DeLorean
find /important/data/ -print | /path/to/delorean.pl /backup/directory/
