sleep 10
/usr/bin/import -window root "screen_0.jpg" -crop "$2"
rm "screen_0-1.jpg" "screen_0-2.jpg" "screen_0-3.jpg"
for i in `seq -w 1 $1`; do
    notify-send -t 1 Press Next
    sleep 8
    /usr/bin/import -window root "screen_${i}.jpg" -crop "$2"
    rm "screen_${i}-1.jpg" "screen_${i}-2.jpg" "screen_${i}-3.jpg"
done
convert "screen_*.jpg" presentation_to_pdf.pdf
rm screen_*.jpg

