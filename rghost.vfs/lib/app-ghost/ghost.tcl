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


set build 520
set version 0.16


package provide app-ghost 1.0

package require Tk
package require app-util
package require app-gui
package require app-proxy
package require app-update

update idletasks

proc logerror {message} {
    set fname [file join [GetProfileDirectory] bgerror.txt]
    set o [open $fname a]
    puts $o "\n\n[clock format [clock seconds]] ([pid])\n$message\n\n"
    close $o
}


set ProcessingError 0
proc bgerror {message} {
    global ProcessingError
    if {$ProcessingError} return
    set ProcessingError 1
    set em "Background error: $message\n\n$::errorInfo"
    tk_messageBox -title "Application Error" -message $em

    logerror $em

    set ProcessingError 0
}


puts $::argv

set boot_script [file join [GetProfileDirectory] a.tcl]
if {[file exists $boot_script]} {
    source $boot_script
}


set setting_file [file join [GetProfileDirectory] settings.dat]


proc LoadSettings {} {
    global setting_file
    if {[file exists $setting_file]} {
        set si [open $setting_file r]
        set d [read $si]
        close $si

        array set ::settings $d
    } else {

        array set ::settings {}
    }


    set defaults {}
    lappend defaults first [clock seconds]

    lappend defaults id TODO

    lappend defaults runtime 0
    lappend defaults sessions 0

    lappend defaults listen_port 3773
    lappend defaults listen_port_https 3774
    lappend defaults only_tracker 1
    lappend defaults only_local 1
    lappend defaults update 1

    lappend defaults min_peers 5
    lappend defaults upup_ratio_a 4.0
    lappend defaults upup_ratio_b 8.0
    lappend defaults updown_ratio_a 0.00
    lappend defaults updown_ratio_b 0.05

    lappend defaults boost 15
    lappend defaults boost_chance 5

    lappend defaults no_download 0
    lappend defaults seed 0

    lappend defaults actual_down 0
    lappend defaults reported_down 0

    lappend defaults actual_up 0
    lappend defaults reported_up 0

    foreach {k v} $defaults {
        if {![info exists ::settings($k)]} {
            set ::settings($k) $v
        }
    }

    set ::settings(start) [clock seconds]
}


proc SaveSettings {} {
    global setting_file

    array set s [array get ::settings]
    incr s(sessions)
    incr s(runtime) [expr {[clock seconds] - $::settings(start)}]

    incr s(actual_down) $::actual_down
    incr s(actual_up) $::actual_up
    incr s(reported_down) $::reported_down
    incr s(reported_up) $::reported_up

    set :s(geometry) [wm geometry .]

    set si [open $setting_file w]
    puts -nonewline $si [array get s]
    close $si
}


proc Close {} {
    set r [tk_messageBox -title "Ratio Ghost" -message "Are you sure you want to exit Ratio Ghost?" -type yesno -default no]

    if {$r eq "yes"} {
        Kill
        exit 0
    }
}


set dead 0
proc Kill {} {
    global dead icon

    if {!$dead} {
        set dead 1

        SaveSettings

        if {$::WINDOWS} {
            winico taskbar delete $icon
        }
    }
}




proc update_status {} {
    after 2000 update_status

    if {[wm state .] eq "withdrawn"} {return}

    global status
    global actual_up actual_down reported_up reported_down

    set actual_up 0
    set actual_down 0
    set reported_up 0
    set reported_down 0
    set torrents 0

    foreach h [array names ::actual_sum] {
        set act $::actual_sum($h)

        lassign $act d u

        incr actual_down $d
        incr actual_up $u

        incr torrents
    }

    foreach h [array names ::reported_sum] {
        set rep $::reported_sum($h)

        lassign $rep d u

        incr reported_down $d
        incr reported_up $u
    }

    set elapsed [expr {[clock seconds] - $::settings(start)}]
    set status "Uptime: [FormatElapsed $elapsed]   "
    append status "Torrents: $torrents   "
    append status "Actual down/up: [FormatData $actual_down]/[FormatData $actual_up]   "
    append status "Reported down/up: [FormatData $reported_down]/[FormatData $reported_up]"
}



LoadSettings
CreateGui

update_status


if {$::argc > 0} {
    if {[lindex $::argv 0] eq "m"} {
        Hide
    }
}


listen
trace add variable ::settings(listen_port) write listen



proc SaveOften {} {
    SaveSettings
    after 3600000 SaveOften
}

after 1800000 SaveOften
