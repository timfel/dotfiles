sleep 10
/usr/bin/import -window root "screen_0.jpg" -crop "$2"
for i in `seq -w 1 $1`; do
    notify-send -t 1 Press Next
    sleep 8
    /usr/bin/import -window root "screen_${i}.jpg" -crop "$2"
done
rm "screen_*-1.jpg"
convert "screen_*.jpg" presentation_to_pdf.pdf
rm screen_*.jpg

