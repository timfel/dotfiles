COUNTER=1
MAX=$1
echo "Sleeping for 10 seconds, so you can get the presentation ready. Then I'll record $MAX slides."
sleep 10
for i in `seq -w 1 $MAX`; do
    FILENAME="slide_${i}.jpg"

    import -window root $FILENAME
    xdotool key space
    sleep 2
done
import -window root "slide_$[MAX + 1].jpg"

convert slide_*.jpg slideshow.pdf
rm slide_*.jpg
