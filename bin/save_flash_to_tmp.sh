for FILE in $(lsof -n | grep "Flash.*deleted" | awk '{printf "/proc/" $2 "/fd/"; sub(/[a-z]+/,"",$4); print $4}'); do
    cp $FILE /tmp/flashvideo-${FILE##*/}.flv
done
