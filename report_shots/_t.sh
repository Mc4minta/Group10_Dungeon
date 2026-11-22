grep -E "^f=(1[0-9]0|2[0-9]0|3[0-9]0|4[0-9]0|5[0-9]0|6[0-9]0|700|DONE)|DONE" /tmp/g10dense/A.log | cut -c1-75; tail -c 200 /tmp/g10dense/B.log | cut -c1-80
