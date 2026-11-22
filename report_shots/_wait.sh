# _wait.sh <job>  wait until /tmp/g10dense/<job>.log has DONE
until grep -q DONE /tmp/g10dense/$1.log 2>/dev/null; do sleep 5; done; echo $1 done
