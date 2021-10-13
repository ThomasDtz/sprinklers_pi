#!/bin/bash

# Set to 1 to not email if no records found. Any other value will send email regardless.
SUPPRESS_EMAIL=1

# sprinklers pi log database location
DB=/usr/local/etc/sprinklers_pi/db.sql

# temporary file to write output to for sending email
TMPFILE=/tmp/sprinklerreport.txt

# list of zone names
declare -a zones=("Z0" "Teich" "Hinne Beet" "Gemuese Beet" "Hecke hinten" "Toepfe" "Vorgarten Beet" "Vorgarten Hecke" "Z8")

if ! hash bc 2>/dev/null ; then
  echo bc is required. Try "sudo apt-get install bc".
  exit 2
fi

if ! hash sqlite3 2>/dev/null ; then
  echo sqlite3 is required. Try "sudo apt-get install sqlite3".
  exit 2
fi

if [ $# -lt 1 -o $# -gt 2 ] ; then
  echo "Usage: $0 [hours] [email]"
  echo "hours: (required) number of hours in the past to report for."
  echo "email: (optional) email address to send report to. If no email then prints to screen."
  exit 1
fi

HOURS=$1

if [ $# -eq 2 ] ; then
  if ! hash mail 2>/dev/null ; then
    echo 'mail program is required to send email. Try "sudo apt-get install heirloom-mailx ssmtp" or "sudo apt-get install ssmtp mailutils mpack"'
    echo "If you've never setup email on this system you should read this about setting up ssmtp https://github.com/rszimm/sprinklers_pi/issues/140#issuecomment-490645483"
    exit 2
  fi
  EMAIL=$2
else
  EMAIL=ECHO
fi

calc () {
    bc <<< "$@"
}

DATE=`date +%s`

TIMEZONE=`date +%z`
TIMEZONE=`calc ${TIMEZONE/+/} / 100`
TIMESPAN=`calc "($HOURS - $TIMEZONE) * 3600"`
TIME=`calc $DATE - $TIMESPAN`
DATE2=`date "+%a %d %b %Y %H:%M:%S"`

echo -e "Sprinkler Report for $HOURS hours preceeding\n\r$DATE2\n" > $TMPFILE

#check if any zones ran
ROWS=`sqlite3 $DB "SELECT COUNT(*) FROM zonelog WHERE date > $TIME" | tr -d '\n'`
if [ $ROWS -gt 1 ] ; then
  #get average seasonal adjustment
  SEASON=`sqlite3 $DB "SELECT AVG(seasonal) FROM zonelog WHERE date > $TIME AND seasonal >= 0" | tr -d '\n'`
  if [ "x$SEASON" != "x" ] ; then
    SEASON2=$(printf "%6.1f" "$SEASON")
    echo "$SEASON2 %  Seasonal Adjustment" >> $TMPFILE
  fi
  
  #get average wunderground adjustment
  WUN=`sqlite3 $DB "SELECT AVG(wunderground) FROM zonelog WHERE date > $TIME AND wunderground >= 0" | tr -d '\n'`
  if [ "x$WUN" != "x" ] ; then
    WUN2=$(printf "%6.1f" "$WUN")
    echo "$WUN2 %  Weather Adjustment" >> $TMPFILE
  fi
  echo "-----------------------------" >> $TMPFILE
  #print each zones runtime
  for i in {1..7} ; do
    LOG=`sqlite3 $DB "SELECT SUM(duration) FROM zonelog WHERE zone = $i AND date > $TIME" | tr -d '\n'`
    if [ "x$LOG" = "x" ] ; then
	LOG=0
    fi

    LOG_MINUTES=`calc "scale=2; $LOG / 60"`

    ZONEINFO="$(printf "%6.2f" "$LOG_MINUTES") [min]\t${zones[$i]}"
    echo -e "$ZONEINFO" >> $TMPFILE

 #   ZONENAME=$(printf "%-15s" "${zones[$i]}")
 #   LOGTIME=$(printf "%5.2f" "$LOG")
 #   echo -e "$ZONENAME : $LOGTIME \tminutes." >> $TMPFILE
 #   #echo -e "$ZONENAME : $LOG \tminutes." >> $TMPFILE
 #   #echo -e "${zones[$i]} : \t$LOG \tminutes." >> $TMPFILE
    
  done
else
  echo "No zones active for this time period." >> $TMPFILE
  if [ $SUPPRESS_EMAIL -eq 1 ] ; then
    EMAIL=ECHO
  fi
fi

#output to screen or email
if [ "$EMAIL" == "ECHO" ] ; then
  cat $TMPFILE
else
  cat $TMPFILE | mail -s "Sprinkler Report $DATE2" $EMAIL
fi

rm $TMPFILE
