auto-haproxy
============

Automatically detects hosts in the area AWS (Amanzon Web Service) and add it to haproxy.cfg

	 Marcelo Santiago < marcelo.santiago /\*NOSPAM\*/ youlinked /(\.)/ com >
	 Wesley Leite    < wesleyhenrique /\*NOSPAM\*/ gmail /(\.)/ com>

#CLONE

	$ cd /opt
	$ git clone https://github.com/wesleyleite/auto-haproxy.git

#INSTALL
	_Edit file hacfg-sr.cfg with information of struct and webserver_

    $ sudo ./auto-haproxy.bash -i

#HELP
	
    $ ./auto-haproxy.bash -h

#CRONTAB

    */2 * * * *  /opt/auto-haproxy/auto-haproxy.bash -r

#LOG

	$ sudo tail -f /var/log/syslog | grep auto-haproxy
	
  	OR

  	$ sudo tail -f /var/log/messages | grep auto-haproxy

