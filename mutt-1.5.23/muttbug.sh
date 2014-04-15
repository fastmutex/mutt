#!/bin/sh

#
#     File a bug against the Mutt mail user agent.
#

# 
#     $Id$
#

#
#     Copyright (c) 2000 Thomas Roessler <roessler@does-not-exist.org>
#
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software
#     Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

SUBMIT="fleas@mutt.org"
DEBIAN_SUBMIT="submit@bugs.debian.org"

prefix=/usr/local

DEBUGGER=/usr/bin/gdb
SENDMAIL=/usr/sbin/sendmail
sysconfdir=${prefix}/etc
pkgdatadir=@pkgdatadir@

include_file ()
{
	echo
	echo "--- Begin $1"
	sed -e '/^[	 ]*#/d; /^[	 ]*$/d; s/^-/- -/' $1
	echo "--- End $1"
	echo
}

debug_gdb ()
{
	cat << EOF > $SCRATCH/gdb.rc
bt
list
quit
EOF
	$DEBUGGER -n -x $SCRATCH/gdb.rc -c $CORE mutt
}

debug_dbx ()
{
	cat << EOF > $SCRATCH/dbx.rc
where
list
quit
EOF
	$DEBUGGER -s $SCRATCH/dbx.rc mutt $CORE
}

debug_sdb ()
{
	cat << EOF > $SCRATCH/sdb.rc
t
w
q
EOF
	$DEBUGGER mutt $CORE < $SCRATCH/sdb.rc
}

case `echo -n` in
"") n=-n; c=   ;;
 *) n=; c='\c' ;;
esac
 

exec > /dev/tty
exec < /dev/tty

SCRATCH=${TMPDIR-/tmp}/`basename $0`.`hostname`.$$

mkdir ${SCRATCH} || \
{ 
	echo "`basename $0`: Can't create temporary directory." >& 2 ; 
	exit 1 ; 
}

trap "rm -r -f ${SCRATCH} ; trap '' 0 ; exit" 0 1 2

TEMPLATE=${SCRATCH}/template.txt

if test -z "$EMAIL" ; then
	EMAIL="`mutt -Q from 2> /dev/null | sed -e 's/^from=.\(.*\).$/\1/'`"
fi

EMAILTMP=''
while test -z "$EMAILTMP"
do
  echo "Please enter your e-mail address [$EMAIL]:"
  echo $n "> $c"
  read EMAILTMP

  if test -z "$EMAILTMP"; then EMAILTMP="$EMAIL"; fi

  if ! echo "$EMAILTMP" | grep -q @
  then
    echo "$EMAILTMP does not appear to be a valid email address"
    EMAILTMP=''
    continue
  fi

  EMAIL="$EMAILTMP"
done

echo "Please enter a one-line description of the problem you experience:"
echo $n "> $c"
read SUBJECT

cat <<EOF  
What should the severity for this bug report be?

       0) Feature request, or maybe a bug which is very difficult to
       fix due to major design considerations.

       1) The package fails to perform correctly in some conditions,
       or on some systems, or fails to comply with current policy
       documents. Most bugs are in this category.

       2) This bug makes this version of the package unsuitable for
       a stable release.

       3) Dangerous bug. Makes the package in question unusable by
       anyone or mostly so, or causes data loss, or introduces a
       security hole allowing access to the accounts of users who
       use the package.

       4) Critical bug. Makes unrelated software on the system (or
       the whole system) break, or causes serious data loss, or
       introduces a security hole on systems where you install the
       package.

EOF
echo $n "Severity? [01234] $c"
read severity
case "$severity" in
0|[Ww]) severity=wishlist  ;;
2|[Ii]) severity=important ;;
3|[Gg]) severity=grave     ;;
4|[Cc]) severity=critical  ;;
     *) severity=normal    ;;
esac

if test -x $DEBUGGER ; then
	test -f core && CORE=core
	echo "If mutt has crashed, it may have saved some program state in"
	echo "a file named core.  We can include this information with the bug"
	echo "report if you wish so."
	echo "Do you want to include information gathered from a core file?"
	echo "If yes, please enter the path - otherwise just say no: [$CORE]"
	echo $n "> $c"
	read _CORE
	test "$_CORE" && CORE="$_CORE"
fi

echo $n "Do you want to include your personal mutt configuration files? [Y|n] $c"
read personal
case "$personal" in
[nN]*)  personal=no  ;;
    *)  personal=yes ;;
esac

echo $n "Do you want to include your system's global mutt configuration file? [Y|n] $c"
read global
case "$global" in
[nN]*)  global=no  ;;
    *)	global=yes ;;
esac

if test -f /etc/debian_version ; then
	DEBIAN=yes
	echo $n "Checking whether mutt has been installed as a package... $c"
	DEBIANVERSION="`dpkg -l mutt | grep '^[ih]' | awk '{print $3}'`" 2> /dev/null
	if test "$DEBIANVERSION" ; then
		DPKG=yes
	else
		DPKG=no
		unset DEBIANVERSION
	fi
	echo "$DPKG"
	echo $n "File this bug with Debian? [Y|n] $c"
	read DPKG
	case "$DPKG" in
	[nN])	DPKG=no ;;
	*)	DPKG=yes ;;
	esac
else
	DEBIAN=no
	DPKG=no
fi

if rpm -q mutt > /dev/null 2> /dev/null ; then
	echo "Mutt seems to come from an RPM package."
	RPMVERSION="`rpm -q mutt`"
	RPMPACKAGER="`rpm -q -i mutt | sed -n -e 's/^Packager *: *//p'`"
fi

MUTTVERSION="`mutt -v | awk '{print $2; exit; }'`"
test "$DPKG" = "yes" && SUBMIT="$SUBMIT, $DEBIAN_SUBMIT"

exec > ${TEMPLATE}

test "$EMAIL"        && echo "From: $EMAIL"
test "$REPLYTO"      && echo "Reply-To: $REPLYTO"
test "$ORGANIZATION" && echo "Organization: $ORGANIZATION"

echo "Subject: mutt-$MUTTVERSION: $SUBJECT"
echo "To: $SUBMIT"
test "$EMAIL" 	     && echo "Bcc: ${EMAIL}"
echo
echo "Package: mutt"
echo "Version: ${DEBIANVERSION-${RPMVERSION-$MUTTVERSION}}"
echo "Severity: $severity"
echo 
echo "-- Please type your report below this line"
echo
echo
echo

if test "$DEBIAN" = "yes" ; then
	echo "Obtaining Debian-specific information..." > /dev/tty
	bug -p -s dummy mutt < /dev/null 2> /dev/null |        \
		sed -n -e "/^-- System Information/,/^---/p" | \
		grep -v '^---'
else
	echo "-- System Information"
	echo "System Version: `uname -a`"
	test -z "$RPMPACKAGER" || echo "RPM Packager: $RPMPACKAGER";
	test -f /etc/redhat-release && echo "RedHat Release: `cat /etc/redhat-release`"
	test -f /etc/SuSE-release && echo "SuSE Release: `sed 1q /etc/SuSE-release`"
	# Please provide more of these if you have any.
fi

echo
echo "-- Mutt Version Information"
echo
LC_ALL=C mutt -v

if test "$CORE" && test -f "$CORE" ; then
	echo 
	echo "-- Core Dump Analysis Output"
	echo

	case "$DEBUGGER" in
		*sdb) debug_sdb $CORE ;;
		*dbx) debug_dbx $CORE ;;
		*gdb) debug_gdb $CORE ;;
	esac
	
	echo
fi

if test "$personal" = "yes" ; then
	CANDIDATES=".muttrc-${MUTTVERSION} .muttrc .mutt/muttrc-${MUTTVERSION} .mutt/muttrc"
	MATCHED="none"
	for f in $CANDIDATES; do
		if test -f "${HOME}/$f" ; then
			MATCHED="${HOME}/$f"
			break
	        fi
	done
	
	if test "$MATCHED" = "none" ; then
		echo "Warning: Can't find your personal .muttrc." >&2
	else
		include_file $MATCHED
	fi
fi


if test "$global" = "yes" ; then
	CANDIDATES="Muttrc-${MUTTVERSION} Muttrc"
	DIRECTORIES="$sysconfdir $pkgdatadir"
	MATCHED="none"
	for d in $DIRECTORIES ; do
		for f in $CANDIDATES; do
			if test -f $d/$f ; then
				MATCHED="$d/$f"
				break
			fi
		done
		test "$MATCHED" = "none" || break
	done
	
	if test "$MATCHED" = "none" ; then
		echo "Warning: Can't find global Muttrc." >&2
	else
		include_file $MATCHED
	fi
fi

exec > /dev/tty

cp $TEMPLATE $SCRATCH/mutt-bug.txt

input="e"
while : ; do
	if test "$input" = "e" ; then
		${VISUAL-${EDITOR-vi}} $SCRATCH/mutt-bug.txt
		if cmp $SCRATCH/mutt-bug.txt ${TEMPLATE} > /dev/null ; then
			echo "Warning: Bug report was not modified!"
		fi
	fi
	
	echo $n "Submit, Edit, View, Quit? [S|e|v|q] $c"
	read _input
	input="`echo $_input | tr EVSQ evsq`"
	case $input in
	e*)	;;
	v*)	${PAGER-more} $SCRATCH/mutt-bug.txt ;;
	s*|"")	$SENDMAIL -t < $SCRATCH/mutt-bug.txt ; exit ;;
	q*)	exit
	esac
done

