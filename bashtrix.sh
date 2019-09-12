#!/bin/bash

# set your matrix ID & server URL, and the room you want to chat in:
USERNAME='@matthewtest7:matrix.org'
SERVER='https://matrix.org'
ROOM=`jq -Rr @uri <<< '#test:matrix.org'` # abusing jq to uri escape

# prompt for a password; log in and grab an access_token
read -s -p "Password for $USERNAME: " PASSWORD; echo
TOKEN=`curl -s -X POST $SERVER/_matrix/client/r0/login --data '{ "type": "m.login.password", "user": "'"$USERNAME"'", "password": "'"$PASSWORD"'" }' | jq -r .access_token`

# resolve the room alias (#test:matrix.org) to a room ID (!vfFxDRtZSSdspfTSEr:matrix.org)
ROOM_ID=`curl -s "$SERVER/_matrix/client/r0/directory/room/$ROOM" | jq -r .room_id`

# check that you're joined to the room (redundant if you know you're already there)
curl -s -X POST "$SERVER/_matrix/client/r0/join/$ROOM?access_token=$TOKEN" > /dev/null

# clean up the sync loop nicely on exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# set a background loop running to receive messages, and use jq to filter out the
# messages for the room you care about from the sync response.  For now we print them
# as JSON pretty-printed by jq, but that's not too bad.
(while true;
    do SYNC=`curl -s "$SERVER/_matrix/client/r0/sync?access_token=$TOKEN&timeout=30000&$SINCE"`
    echo $SYNC | jq -r ".rooms.join.\"$ROOM_ID\".timeline.events"
    SINCE="since=`echo $SYNC | jq -r .next_batch`"
done) &

# set a foreground loop running to prompt for your own messages and send them
# into the room as plaintext.
ROOM_ID=`jq -Rr @uri <<< $ROOM_ID` # uri escape room_id
while true;
    do read -p "<$USERNAME> " INPUT
    curl -s -X PUT "$SERVER/_matrix/client/r0/rooms/$ROOM_ID/send/m.room.message/m.`date +%s`?access_token=$TOKEN" --data '{"body": "'"$INPUT"'", "msgtype": "m.text"}'
done
