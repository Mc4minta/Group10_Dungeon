for j in B C D E G; do echo $j $(ls /tmp/g10dense/${j}_f*.bmp 2>/dev/null | tail -1) ; done
