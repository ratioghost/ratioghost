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


package provide app-update 1.0
package require app-util
package require http

set os NA
if {$::WINDOWS} {set os W}
if {$::LINUX} {set os L}
if {$::MAC} {set os M}


::http::config -useragent "RATIO-GHOST-$os-$build"

set check 0
set skip_update 0
set checking_update 0

proc check_for_updates {} {
    global build check

    incr check

    set url "http://ratioghost.com/update?version=$build&check=$check"

    if {$::settings(update)} {
        puts "Checking for updates"

        if {[set ec [catch {set r [::http::geturl $url -command update_complete -timeout 60000]} err]]} {
            puts "Couldn't check for update:"
            puts "error:$ec $err"
        }

    }

    after [expr {1000 * 60 * 60 * 2}] check_for_updates
}


proc update_complete {r} {
    if {$::skip_update} return
    if {$::checking_update} return

    set ::checking_update 1

    set ncode [::http::ncode $r]
    set data [::http::data $r]

    puts "Received update info: $ncode"

    if {$ncode == 200 && [string match *yes* $data]} {
        set r [tk_messageBox -title "Ratio Ghost Update Available" -message "There is a new version of Ratio Ghost available. Updating to the latest version is highly recommended. Would you like to update now?" -type yesno]
        if {$r eq {yes}} {
            OpenDocument http://RatioGhost.com/download
        } else {
            set ::skip_update 1
        }
    }

    set ::checking_update 0

    ::http::cleanup $r
}



after 15000 check_for_updates
