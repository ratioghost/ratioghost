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


package provide app-gui 1.0
package require tooltip
package require autoscroll


if {$::WINDOWS} {
package require Winico 0.6
}

proc CreateGui {} {
    global status
    set status ""

    option add *tearOff 0

    wm withdraw .
    update idletasks
    wm title . "Ratio Ghost"

    menu .menubar
    . configure -menu .menubar

    menu .menubar.file
    .menubar add cascade -menu .menubar.file -label File -underline 0
    if {$::WINDOWS} {.menubar.file add command -label "Hide" -underline 0 -command {Hide}}
    .menubar.file add command -label "Exit" -underline 1 -command {Close}

    menu .menubar.help
    .menubar add cascade -menu .menubar.help -label Help -underline 0
    .menubar.help add command -label "Show Debugging Console" -underline 5 -command {console show}
    .menubar.help add separator
    .menubar.help add command -label "Usage Statistics" -underline 6 -command {show_stats}
    .menubar.help add command -label "Visit Website" -underline 6 -command {show_website}
    .menubar.help add command -label "About" -underline 0 -command {show_about}


    if {!$::MAC} {
        set logofn logo.png
        set logo [image create photo -file $logofn]
        set cv [ttk::label .logo -image $logo -anchor center]
        grid $cv -sticky nsew -pady 20 -padx 30
        grid rowconfigure . 0 -weight 0
    }

    set nb [ttk::notebook .nb]

    set log [CreateLog .nb.log]
    $nb add $log -text Log

    set options [CreateOptions .nb.options]
    $nb add $options -text Options


    .nb select .nb.log

    grid $nb -sticky nsew
    grid columnconfigure . all -weight 1
    grid rowconfigure . 1 -weight 1

    grid [ttk::label .status -textvariable status -anchor center] -sticky ew


    if {[info exists ::settings(geometry)]} {
        wm geometry . $::settings(geometry)
    }

    wm deiconify .


    bind . <ButtonPress> "focus %W"
    bind . <Destroy> Kill

    wm protocol . WM_DELETE_WINDOW {
        if {$::WINDOWS} {
            Hide
        } else {
            Close
        }
    }

    CreateTrayIcon
}



proc CreateTrayIcon {} {
    if {!$::WINDOWS} return
    global tray_menu icon

    set icon [winico load TK]

    set tray_menu [menu .popup]
    $tray_menu add command -label "Hide Ratio Ghost" -command Hide -underline 6
    $tray_menu add command -label "Exit" -command Close -underline 2

    winico taskbar add $icon -pos 0 -callback [list TrayCallback %m %x %y]
    winico taskbar modify $icon -text "Ratio Ghost - Running"
}


proc TrayCallback {msg x y} {
    global tray_menu
    switch -exact -- $msg {
        WM_RBUTTONDOWN {
            $tray_menu post $x $y
        }
        WM_LBUTTONDOWN {
            $tray_menu post $x $y
        }
        WM_LBUTTONDBLCLK {
            Hide
        }
    }
}


proc Hide {} {
    if {!$::WINDOWS} return

    global last_state tray_menu
    if {[wm state .] eq "withdrawn"} {
        $tray_menu entryconfigure 0 -label "Hide Ratio Ghost" -underline 6
        wm state . $last_state
        wm deiconify .
    } else {
        $tray_menu entryconfigure 0 -label "Show Ratio Ghost" -underline 6
        set last_state [wm state .]
        wm withdraw .
    }
}


proc CreateLog {name} {
    global lb

    ttk::frame $name -padding 20

    set lb [listbox $name.l1 -selectmode single -yscrollcommand [list $name.scroll set]]
    set scroll [scrollbar $name.scroll -orient vertical -command [list $lb yview]]
    grid $lb $scroll -sticky nsew

    grid columnconfigure $name 0 -weight 1
    grid rowconfigure $name 0 -weight 1

    ::autoscroll::autoscroll $scroll

    bind $lb <Double-ButtonPress-1> [list EventLogShow %W %x %y]

    return $name
}


set example {}

proc CreateOptions {name} {
    ttk::frame $name -padding 20


    set warning [ttk::label $name.warn -foreground red -anchor center -text "It is highly recommended that you close your torrent client before changing any settings here."]

    set ratio [ttk::labelframe $name.ratio -text "Ratio Options" -padding 12]

    set lpeer [ttk::label $ratio.lpeer -text "If torrent has less than " -anchor e]
    set epeer [ttk::entry $ratio.epeer -textvariable ::settings(min_peers) -validate key -validatecommand {ValidatePer %P} -width 7]
    set lpeer2 [ttk::label $ratio.lpeer2 -text "leechers, then report only the actual upload amount" -anchor w]
    grid $lpeer $epeer $lpeer2 - - - -padx 4 -pady 4 -sticky ew



    grid [ttk::frame $ratio.space1] -pady 6

    set lother [ttk::label $ratio.lother -text "Otherwise, report the actual upload amount..." -anchor w]
    set lratd [ttk::label $ratio.lratd -text "plus between" -anchor e]
    set ratad [ttk::entry $ratio.ratad -textvariable ::settings(updown_ratio_a) -validate key -validatecommand {ValidateReal %P} -width 7]
    set landd [ttk::label $ratio.landd -text "and"]
    set ratbd [ttk::entry $ratio.ratbd -textvariable ::settings(updown_ratio_b) -validate key -validatecommand {ValidateReal %P} -width 7]
    set ltimed [ttk::label $ratio.ltimed -text "times actual download"]
    grid $lother - - - - -padx 4 -pady 4 -sticky ew
    grid $lratd $ratad $landd $ratbd $ltimed -padx 4 -pady 4 -sticky ew


    set lrat [ttk::label $ratio.lrat -text "plus between" -anchor e]
    set rata [ttk::entry $ratio.rata -textvariable ::settings(upup_ratio_a) -validate key -validatecommand {ValidateReal %P} -width 7]
    set land [ttk::label $ratio.land -text "and"]
    set ratb [ttk::entry $ratio.ratb -textvariable ::settings(upup_ratio_b) -validate key -validatecommand {ValidateReal %P} -width 7]
    set ltime [ttk::label $ratio.ltime -text "times actual upload"]
    grid $lrat $rata $land $ratb $ltime -padx 4 -pady 4 -sticky ew



    set lb1 [ttk::label $ratio.lb1 -text "plus up to" -anchor e]
    set lb [ttk::entry $ratio.lb -textvariable ::settings(boost) -validate key -validatecommand {ValidateReal %P} -width 7]
    set lpc [ttk::label $ratio.lpc -text "KB/s with"]
    set bp [ttk::entry $ratio.bp -textvariable ::settings(boost_chance) -validate key -validatecommand {ValidatePer %P} -width 7]
    set lkb [ttk::label $ratio.lkb -text "percent chance"]

    grid $lb1 $lb $lpc $bp $lkb  -padx 4 -pady 4 -sticky ew



    grid [ttk::frame $ratio.space2] -pady 6


    set chk_ndown [ttk::checkbutton $ratio.chk_ndown -text "Report download as zero" -variable ::settings(no_download)]
    tooltip::tooltip $chk_ndown "AKA FreeLeech. This will report the amount downloaded as zero.\nIt will also block the complete flag when your download finishes.\nYou will still get credit for your upload."
    grid x $chk_ndown - - - -padx 4 -pady 4 -sticky w

    set chk_seed [ttk::checkbutton $ratio.chk_seed -text "Pretend to seed" -variable ::settings(seed)]
    tooltip::tooltip $chk_seed "This will set the reported amount left as zero, making you appear as a seed.\nMany servers don't send peer lists to seeds - this can slow your download."
    grid x $chk_seed - - - -padx 4 -pady 4 -sticky w



    SetExample

    set example_frame [ttk::labelframe $ratio.exf -text "Example" -padding 12]
    grid $example_frame -row 1 -column 5 -rowspan 8

    set lexample [ttk::label $example_frame.lexample -textvariable ::example -anchor w]
    grid $lexample -sticky nsew


    grid columnconfigure $ratio 4 -weight 1


    set k [list apply [list {args} "
        if {\$::settings(seed)} {
            set ::settings(no_download) 1
            $chk_ndown configure -state disabled
        } else {
            $chk_ndown configure -state normal
        }
    "]]

    trace add variable ::settings(seed) write $k

    set ::settings(seed) $::settings(seed)


    trace add variable ::settings write SetExample

    set connection [ttk::labelframe $name.connection -text "Connection Options" -padding 12]

    set l3 [ttk::label $connection.l3 -text "Listen for incoming connections on port" -anchor e]
    set e3 [ttk::entry $connection.e3 -textvariable ::settings(listen_port) -validate key -validatecommand {ValidatePort %P} -width 7]
    tooltip::tooltip $e3 "What port Ratio Ghost listens on.\nLeave this set to 3773 unless you're using that port for something else."
    grid $l3 $e3 -padx 4 -pady 4 -sticky ew

    set chk_tracker [ttk::checkbutton $connection.chk_tracker -text "Accept only tracker traffic" -variable ::settings(only_tracker)]
    tooltip::tooltip $chk_tracker "This will block proxy traffic that doesn't appear to be torrent tracker related.\nThis option may break your torrent client's update feature, and it may block ads if your torrent client is ad supported."
    grid x $chk_tracker - - -padx 4 -pady 4 -sticky w

    set chk_local [ttk::checkbutton $connection.chk_local -text "Accept only local connections" -variable ::settings(only_local)]
    tooltip::tooltip $chk_local "This will block proxy traffic that isn't coming from your computer.\nLeave this checked for security unless you know what you're doing."
    grid x $chk_local - - -padx 4 -pady 4 -sticky w

    set chk_update [ttk::checkbutton $connection.chk_update -text "Automatically check for software updates" -variable ::settings(update)]
    tooltip::tooltip $chk_update "New versions of Ratio Ghost are released occasionally that may add features or improve stealth.\nChecking this will notify you when an update is available."
    grid x $chk_update - - -padx 4 -pady 4 -sticky w



    grid $warning -sticky ew -pady 10
    grid $ratio -sticky ew -pady 10
    grid $connection -sticky ew -pady 10
    grid columnconfigure $name 0 -weight 1

    return $name
}


proc SetExample {args} {
    global example settings

    set example ""

    append example "If the torrent has less than $settings(min_peers) leechers:"
    append example "\nThe reported download will be"
    if {$settings(no_download)} {
        append example " 0."
    } else {
        append example " your actual download."
    }

    append example "\nThe reported upload will be your actual upload."


    append example "\n\nIf the torrent has at least $settings(min_peers) leechers:"
    append example "\nThe reported download will be"
    if {$settings(no_download)} {
        append example " 0."
    } else {
        append example " your actual download."
    }
    append example "\nThe reported upload will be your actual upload"
    append example "\nand between $settings(updown_ratio_a) and $settings(updown_ratio_b) times your actual download"
    append example "\nand between $settings(upup_ratio_a) and $settings(upup_ratio_b) times your actual upload"
    append example "\nand $settings(boost_chance) percent of the time an extra 0-$settings(boost) KB/s."
}


set EventIndexDel 0
set EventIndex 0

proc Event {what} {
    global lb
    set ts [clock format [clock seconds] -format %I:%M%P]
    set what "$ts $what"

    $lb insert end $what
    incr ::EventIndex

    if {[$lb size] > 512} {
        incr ::EventIndexDel
        $lb delete 0
    }

    return [expr {$::EventIndex - 1}]
}


proc EventAppend {idx what} {
    global lb

    if {$idx eq ""} {return}

    set idx [expr {$idx - $::EventIndexDel}]
    if {$idx < 0} return

    set t [$lb get $idx]
    append t $what
    $lb delete $idx
    $lb insert $idx $t
}



proc EventLogShow {window x y} {

    set idx [$window curselection]
    set idx [expr {$idx + $::EventIndexDel}]

    if {![info exists ::log_lookup($idx)]} {
        return
    }
    if {![info exists ::event_log($::log_lookup($idx))]} {
        return
    }

    set n .eventlog$idx

    if {[info commands $n] ne {}} {
        destroy $n
    }

    set t [toplevel $n]
    wm title $t "Event $idx"

    #wm resizable $t 0 0

    set f [ttk::frame $t.f -padding 20]
    grid $f -sticky nsew

    set l [ttk::label $f.stats -text $::event_log($::log_lookup($idx))]
    grid $l

    focus $t
}



proc show_stats {} {

    if {[info commands .stats] ne {}} {
        destroy .stats
    }

    set t [toplevel .stats]
    wm title $t "RG Usage"

    wm resizable $t 0 0

    set f [ttk::frame $t.f -padding 20]
    grid $f -sticky nsew


    set stats ""

    append stats "First use on: [clock format $::settings(first)]\n"
    append stats "Total runtime: [FormatElapsed [expr {$::settings(runtime) + ([clock seconds] - $::settings(start))}]]\n"
    append stats "Total sessions: $::settings(sessions)\n"

    append stats "\nActual total download: [FormatData [expr {$::settings(actual_down) + $::actual_down}]]\n"
    append stats "Actual total upload: [FormatData [expr {$::settings(actual_up) + $::actual_up}]]\n"

    append stats "\nReported total download: [FormatData [expr {$::settings(reported_down) + $::reported_down}]]\n"
    append stats "Reported total upload: [FormatData [expr {$::settings(reported_up) + $::reported_up}]]\n"


    set l [ttk::label $f.stats -text $stats]
    grid $l


    focus $t
}




proc show_about {} {

    if {[info commands .about] ne {}} {
        destroy .about
    }

    set t [toplevel .about]
    wm title $t "RG About"

    wm resizable $t 0 0

    set f [ttk::frame $t.f -padding 20]
    grid $f -sticky nsew


    set about ""

    append about "Ratio Ghost v$::version\n"
    append about "Build $::build\n"
    append about "Made with love!\n"

    set l [ttk::label $f.about -text $about]
    grid $l

    focus $t
}


proc show_website {} {
    OpenDocument http://RatioGhost.com/
}
