#   Ratio Ghost - BitTorrent ratio modifying proxy
#   Copyright (C) 2006-2015 Yasmine@RatioGhost.com
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

set auto_path [linsert $auto_path 0 ./rghost.vfs/lib]

catch {
    package require starkit
    if {[starkit::startup] eq "sourced"} return
}


set WINDOWS [string match Windows* $tcl_platform(os)]
set LINUX [string match Linux* $tcl_platform(os)]
if {!$WINDOWS && !$LINUX} {set MAC 1} else {set MAC 0}


if {$::WINDOWS} {
    package require dde

    set topicName RatioGhost2015

    set otherServices [dde services TclEval $topicName]
    if {[llength $otherServices] > 0} {
        dde execute TclEval $topicName {
            wm deiconify .
            raise .
            bell
        }
        exit
    }

    dde servername $topicName


    if {![info exists env(APPDATA)]} {
        tk_messageBox -icon error -title "Ratio Ghost" -message "Sorry, your version of Windows is not supported. Please consider upgrading."
        exit
    }
}




package require app-ghost
