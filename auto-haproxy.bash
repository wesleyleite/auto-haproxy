#!/bin/bash 

# auto-haproxy.sh 0.1 
#
# Copyright (C) 2014 YOULINKED Free software
# Marcelo Santiago marcelo.santiago (a) youlinked (') com
# Wesley Leite     wesley.leite (a) gmail (') com

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

Usage() {
echo -e "
This script aims to detect online hosts and adds them to haproxy.cfg

Options
\t-r\t\tCreate file roundrobin mode;
\t-s\t\tCreate file source mode;
\t-i\t\tInstall copy files after clone;
\t-h\t\tThis.

Marcelo Santiago  marcelo.santiago (a) youlinked (') com
Wesley Leite      wesley.leite (a) gmail (') com\n"
}

Install() {
	[ ${EUID} -eq 0  ] || {
        	echo "root is need"
        	return 1
    	}

	[ -e '/etc/hacfg-sr.cfg' ] &&
		echo -e "/etc/hacfg-sr.cfg\t[ OK ]" ||
		cp hacfg-sr.cfg /etc/haproxy
    	[ -d '/etc/haproxy.d' ] &&
        	echo -e "/etc/haproxy.d\t[ OK ]" ||
		cp -R haproxy.d /etc/haproxy/

	return 0
}

UpdateVAR()
{
	# Update all variables in /etc/haproxy.d/*
	sed -i "s/{WEBSITE}/${SITE}/g" ${HATXT}
    	sVarSite="$(echo ${SITE} | tr '.' '_')"
	sed -i "s/{VARIAVEL}/${sVarSite}/g" ${HATXT}

	sed -i "s/{HAUSER}/${HAUSER}/; s/{HAPASS}/${HAPASS}/" ${HATXT}

	# BALANCE
	[ "${WORK}" == "rr" ] &&
        	sed -i 's/{BALANCE}/balance     roundrobin/' ${HATXT} ||
        	sed -i 's/{BALANCE}/balance     source/' ${HATXT}
}

UpdateTMPCookie()
{
	local IP=$1
	local hostName=$2
	local nLet

	# finds which the zone the ip address
	nLet="$(echo ${sZona} | grep -Ewo "$(echo ".\:${IP}" | cut -d'.' -f1-4)." | cut -d':' -f1)" 

	# get the last octet of the ip address
	ipHost=$( printf '%03d' $(echo ${IP} | cut -d'.' -f4) )
	# check if it has already been added
	[ -z "$(cat ${HATMP} | grep "${IP}:80" )" ] && {
        [ "${WORK}" == "rr" ] && 
            echo -e "        server\t${hostName}\t ${IP}:80\t cookie ${nLet}${ipHost} maxconn 200 check">>${HATMP} ||
                echo -e "       server\t${hostName}\t ${IP}:80\t check" >> ${HATMP}
		logger "[auto-haproxy]  [+] ${hostName}  [ ${nLet} ]"
	}
}

CheckBalance() {
	# case file sorce mode, so it can be modified to roudrobin or opposed
	local sBalanceTipo="$(grep 'balance' ${HACFG} | awk '{print $2}')"
	[ "${WORK}" == "rr" -a "${sBalanceTipo}" == "source" ] && {
		sed -i '/server/d' ${HACFG}
	}
	[ "${WORK}" == "s"  -a "${sBalanceTipo}" == "roundrobin" ] && {
		sed -i '/server/d' ${HACFG}
	}
}

# start prog
cfgFile="/etc/haproxy/hacfg-sr.cfg"

[ -e "${cfgFile}" ] || return 1
source /etc/haproxy/hacfg-sr.cfg

while getopts irshh: o
do
	case "${o}" in
	h) Usage ;;
	i) Install
	;;
	r|s)
		[ "${o}" == "r" ] && WORK="rr"
		[ "${o}" == "s" ] && WORK="s"

		>${HATXT}
		>${HATMP}

		CheckBalance

		cat ${HACFG} | grep 'server' | grep 'check' > ${HATMP}

		for sLayer in ${aLayer}
        	do
			for Layer in "$( /usr/local/bin/aws opsworks describe-instances --layer-id ${sLayer} \
                    		--output text --query 'Instances[*].{Hostname:Hostname,IP:PrivateIp,Status:Status}' |
                    		grep -i 'online' )"
            		do

				lista=( $(echo $Layer | sed 's/online/ /g') )
				for (( i=0 ; i<=$((${#lista[@]}-1)) ; i+=1 ))
				do
        				[ ! -z "$( echo ${lista[${i}]} |  grep '^[a-zA-Z]' )" ] && {
                				sIp="$(echo "${lista[${i}]}        ${lista[${i}+1]}")"
						aOnlineIp="${aOnlineIp}|${sIp}:80"
						IpAddress="${sIp}|${IpAddress}"
						# it exist in HACFG
						[ -z "$( cat ${HACFG} | grep "${lista[${i}]}" )" ] && {
                   					# send ip address and hostname to update
							UpdateTMPCookie "$(echo ${sIp} | awk '{print $2}')" ${lista[${i}]}
                   					# update variable that can regenerate cfg file
						    DIF=1
						} ||
							logger "[auto-haproxy] No found new host 'on' in ${sLayer}"

						}
                		done
			done
		done

		# enter ip address online at this moment
		lIp="$(echo ${aOnlineIp} | sed 's/^|//;s/|$//' | sed -r 's/[a-zA-Z]//g')"

		# demonstrates the difference which is off
		[ ! -z "$( cat ${HACFG} | grep 'server' | grep 'cookie' | grep -Ev "(${lIp})" )" ] && DIF=1

        [ ${DIF} -eq 1 -a ! -z "$( echo "${lIp}" | sed 's/:80|\|//g')" ] && {
			[ $(cat ${HATMP} | wc -l ) -ne 0 ] && {
				cp ${HACFG}  ${HACFG}.old
				cat ${HAD}/* ${HATMP} > ${HATXT}
        			# update all the variables in haproxy.d in HATXT
				UpdateVAR
				# removes hosts offline in HATXT
				for sOffIp in $( cat ${HACFG} |
                        			grep 'server' |
                        			grep 'check' |
                        			grep -Ev "${lIp}" |
                        			awk '{print $3}' |
                        			cut -d':' -f1 )
				do
					logger "[auto-haproxy] [-] $sOffIp"
					sed -i "/${sOffIp}/d" ${HATXT}
				done
				cp ${HATXT} ${HACFG}
				service haproxy reload
				[ $? -ne 0 ] && {
					logger "[auto-haproxy] [ ERROR ] returns the backup and reload"
					cp ${HACFG}.old ${HACFG}
					service haproxy reload
        			} ||
					logger "[auto-haproxy] Haproxy is running"
			} ||
				logger "[auto-haproxy] An error was found in generation ${HATMP} haproxy.txt"
		} ||
			logger "[auto-haproxy] no changes"
	;;
	esac
done
