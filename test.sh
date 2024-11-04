get_windows_on_top() {
  # Normalize the input window_id by removing leading zeros after "0x"
  local window_id=$(echo "$1" | sed 's/^0x0*/0x/')

  xprop -root _NET_CLIENT_LIST_STACKING |
    sed -e 's/_NET_CLIENT_LIST_STACKING(WINDOW): window id # //;s/,//g' |
    awk -v target="$window_id" '{
            found=0
            for (i=1; i<=NF; i++) {
                # Normalize each xprop window ID by removing leading zeros after "0x"
                id = $i
                sub(/^0x0*/, "0x", id)
                
                if (found) print id
                if (id == target) found=1
            }
        }'
}

whatsapp_id="0x0560000c"
windows_on_top=$(get_windows_on_top "$whatsapp_id")

# Properly display each window ID on a new line
echo "Windows on top of WhatsApp:"
echo "$windows_on_top"
