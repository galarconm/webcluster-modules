#!/bin/bash

cat > index.html <<EOF
    <h1>Greetings Fellas!</h1>
    <p>Database address: ${db_address}</p>
    <p>DB port: ${db_port}</p>
EOF


#echo "Greetings Fellas!" > index.html
nohup busybox httpd -f -p ${server_port} &