# smtp-concierge
File retrieval over SMTP - Tom Van de Wiele 2012

Commands to be sent in the subject of an e-mail to your target address that has maildrop and the following .mailfilter file:
 * .mailfilter:
   *    ``` to "| perl smtp-concierge.pl"```

Possible commands to be put in the subject of your e-mail:

 * Getting a dir listing:
    * ```ls <path>```

 *  Getting a file with no size restriction:
    * ```get file```

 *  Getting a file and spliting it into chunks of 10M each. To be reassembled in Windows using:  ```"copy /b +part1 +part2 bigfile" ``` 
    * ```get bigfile 10```             

 # Configuration Notes for Postfix

 main.cf 
  ``` message_size_limit 20480000
   mailbox_command = /usr/bin/maildrop -d ${USER}
 ```
 /etc/maildroprc
  ```
  include $HOME/.mailfilter
  ```
