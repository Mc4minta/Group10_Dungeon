until grep -q DONE /tmp/g10dense/A.log; do sleep 5; done; grep -E "^f=(1[5-9]0|2[0-9]0|3[0-9]0|4[0-9]0|5[0-9]0|6[0-9]0)" /tmp/g10dense/A.log | cut -c1-70
