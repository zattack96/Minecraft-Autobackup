#!/bin/bash
# MINECRAFT Autobackup By Justin Smith
#   http://www.minecraftforum.net/viewtopic.php?f=10&t=36066
# Modified by Max Malm to support save-on / save-off while doing backup and auto-scp to remote host
#	https://github.com/benjick/Minecraft-Autobackup

#Variables

# DateTime stamp format that is used in the tar file names.
STAMP=`date +%d-%m-%Y_%H%M%S`

# The screen session name, this is so the script knows where to send the save-all command (for autosave)
SCREENNAME="minecraft"

# Whether the script should tell your server to save before backup (requires the server to be running in a screen $
AUTOSAVE=1

# Notify the server when a backup is completed.
NOTIFY=1

# Backups DIR name (NOT FILE PATH)
BACKUPDIR="backups"

# MineCraft server properties file name
PROPFILE="server.properties"

# Enable/Disable (0/1) Automatic CronJob Manager
CRONJOB=1

# When an error occurs it will send it to this e-mail
MAILTO="mail#example.com"

# Update every 'n' Minutes
UPDATEMINS=120

# Delete backups older than 'n' DAYS
OLDBACKUPS=7

# Enable SCP to remote host
SCP=0

# SCP username
SCPUSERNAME="username"

# SCP hostname
SCPHOST="example.com"

# SCP port
SCPPORT=22

# SCP path (create this dir at the remote path)
SCPPATH="/home/username/backup/minecraft"

# Enable/Disable Logging (This will just echo each stage the script reaches, for debugging purposes)
LOGIT=1

# *-------------------------* SCRIPT *-------------------------*
# Set todays backup dir

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Starting Justins AutoBackup Script.."
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Working in directory: $PWD."
fi

BACKUPDATE=`date +%d-%m-%Y`
FINALDIR="$BACKUPDIR/$BACKUPDATE"

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Checking if backup folders exist, if not then create them."
fi

if [ -d $BACKUPDIR ]
then
   echo -n < /dev/null
else
   mkdir "$BACKUPDIR"

   if [ $LOGIT -eq 1 ]
   then
      echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Created Folder: $BACKUPDIR"
   fi

fi

if [ -d "$FINALDIR" ]
then
   echo -n < /dev/null
else
   mkdir "$FINALDIR"
   
   if [ $LOGIT -eq 1 ]
   then
      echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Created Folder: $FINALDIR"
   fi

fi

if [ $OLDBACKUPS -lt 0 ]
then
   OLDBACKUPS=3
fi

# Deletes backups that are 'n' days old
if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Removing backups older than $OLDBACKUPS days."
fi
OLDBACKUP=`find $PWD/$BACKUPDIR -type d -mtime +$OLDBACKUPS | grep -v -x "$PWD/$BACKUPDIR" | xargs rm -rf`

# --Check for dependencies--

#Is this system Linux?
#LOL just kidding, at least it better be...

#Get level-name
if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Fetching Level Name.."
fi

while read line
do
   VARI=`echo $line | cut -d= -f1`
   if [ "$VARI" == "level-name" ]
   then
      WORLD=`echo $line | cut -d= -f2`
   fi
done < "$PROPFILE"

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Level-Name is $WORLD"
fi

BFILE="$WORLD.$STAMP.tar.bz2"
CMD="tar -cfj $FINALDIR/$BFILE $WORLD"
BFILEN="${WORLD}_nether.$STAMP.tar.bz2"
CMDN="tar -cfj $FINALDIR/$BFILEN ${WORLD}_nether"
BFILEE="${WORLD}_the_end.$STAMP.tar.bz2"
CMDE="tar -cfj $FINALDIR/$BFILEE ${WORLD}_the_end"

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Packing and compressing folder: $WORLD to tar file: $FINALDIR/$BFILE"
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Packing and compressing folder: ${WORLD}_nether to tar file: $FINALDIR/$BFILEN"
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Packing and compressing folder: ${WORLD}_the_end to tar file: $FINALDIR/$BFILEE"
fi

if [ $NOTIFY -eq 1 ]
then
   screen -x $SCREENNAME -X stuff "`printf "say Backing up world: \'$WORLD\'\r"`"
fi

#Create timedated backup and create the backup directory if need.
if [ $AUTOSAVE -eq 1 ]
then
   if [ $NOTIFY -eq 1 ]
   then
      screen -x $SCREENNAME -X stuff "`printf "say Forcing Save..\r"`"
   fi
   #Send save-all to the console
   screen -x $SCREENNAME -X stuff `printf "save-all\r"`
   sleep 2
fi

if [ $NOTIFY -eq 1 ]
then
   screen -x $SCREENNAME -X stuff "`printf "say Packing and compressing world...\r"`"
fi

# Run backup command
screen -x $SCREENNAME -X stuff "`printf "save-off\r"`"
$CMD
$CMDN
$CMDE
screen -x $SCREENNAME -X stuff "`printf "save-on\r"`"

# Transfer files via SCP to remote host
if [ $SCP -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Sending files to remote host via SCP"
   scp -P $SCPPORT $FINALDIR/$BFILE $SCPUSERNAME@$SCPHOST:$SCPPATH
fi

if [ $NOTIFY -eq 1 ]
then
   # Tell server the backup was completed.
   screen -x $SCREENNAME -X stuff "`printf "say Backup Completed.\r"`"
fi

# --Cron Job Install--
if [ $CRONJOB -eq 1 ]
then

   #Check if user can use crontab
   if [ -f "/etc/cron.allow" ]
   then
      EXIST=`grep $USER < /etc/cron.allow`
      if [ "$EXIST" != "$USER" ]
      then
         echo "Sorry. You are not allowed to edit cronjobs."
         exit
      fi
   fi

   #Work out crontime
   if [ $UPDATEMINS -eq 0 -o $UPDATEMINS -lt 0 ]
   then
      MINS="*"
   else
      MINS="*/$UPDATEMINS"
   fi

   #Check if cronjob exists, if not then create.
   crontab -l > .crons
   EXIST=`crontab -l | grep $0 | cut -d";" -f2`
   CRONSET="$MINS * * * * cd $PWD;$0"

   if [ "$EXIST" == "$0" ]
   then

      #Check if cron needs updating.
      THECRON=`crontab -l | grep $0`
      if [ "$THECRON" != "$CRONSET" ]
      then
         CRONS=`crontab -l | grep -v "$0"`
         echo "$CRONS" > .crons
         echo "$CRONSET" >> .crons
         crontab .crons
         echo "Cronjob has been updated"
      fi

      rm .crons
      exit
   else
      crontab -l > .crons
      echo "$CRONSET" >> .crons
      crontab .crons
      rm .crons
      echo "Autobackup has been installed."
      exit
   fi

fi
