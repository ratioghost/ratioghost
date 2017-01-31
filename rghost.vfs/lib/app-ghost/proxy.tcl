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


package provide app-proxy 1.0

expr {srand([clock seconds])}

proc prox {local addr port} {
    global linfo lhost

    if {$::settings(only_local)} {
        if {$addr ne "127.0.0.1"} {
            Event "Blocked request from $addr:$port."
            close $local
            return
        }
    }

    dlog_new

    dlog "Accept $local from $addr port $port"
    fileevent $local readable [list read_first $log_num $local]
    set linfo($local) $addr:$port
    set lhost($local) ""
}


proc stats_actual {hash event down up left} {
    global actual_first actual_last actual_sum
    upvar 1 local local

    foreach v [list actual_previous_down actual_previous_up actual_previous_down_diff actual_previous_up_diff] {
        upvar 1 $v $v
        set $v 0
    }

    #puts "Updating actual stats on $hash ($down $up $left)"

    if {![info exists actual_first($hash)]} {
        set actual_first($hash) [list $down $up $left]
    }

    if {![info exists actual_sum($hash)]} {
        set actual_sum($hash) "0 0"
    }

    if {[info exists actual_last($hash)]} {
        if {$event ne {started}} {
            lassign $actual_last($hash) d u l
            lassign $actual_sum($hash) ad au
            set actual_sum($hash) "[expr {($down-$d)+$ad}] [expr {($up-$u)+$au}]"

            set actual_previous_down $d
            set actual_previous_up $u
        }
    }

    set actual_previous_down_diff [expr {$down - $actual_previous_down}]
    set actual_previous_up_diff [expr {$up - $actual_previous_up}]

    set actual_last($hash) [list $down $up $left]
}


proc stats_reported {hash event down up left} {
    global reported_last reported_sum reported_last_time
    upvar 1 local local

    #puts "Updating reported stats on $hash ($down $up $left)"

    if {![info exists reported_sum($hash)]} {
        set reported_sum($hash) "0 0"
    }

    if {[info exists reported_last($hash)]} {
        if {$event ne {started}} {
            lassign $reported_last($hash) d u l
            lassign $reported_sum($hash) ad au
            set reported_sum($hash) "[expr {($down-$d)+$ad}] [expr {($up-$u)+$au}]"
        }
    }

    set reported_last_time($hash) [clock seconds]
    set reported_last($hash) [list $down $up $left]
}


set log_inc 1
proc dlog_new {} {
    upvar 1 log_num log_num
    incr ::log_inc
    set log_num $::log_inc
}


proc dlog {what} {
    upvar 1 log_num log_num
    if {$log_num > 0} {
        #puts $what
        append ::event_log($log_num) "$what\n"
    }
}


proc dlog_set {where} {
    upvar 1 log_num log_num
    set ::log_lookup($where) $log_num
}


array set hosts {}

proc read_first {log_num local} {
    global rinfo first linfo lhost

    fconfigure $local -translation binary
    if {[eof $local] || [catch {set first_part [read $local 3]}]} {
        close $local
        return
    }

    if {!($first_part eq "GET" || $first_part eq "CON")} {
        if {$lhost($local) ne ""} {
            #puts "Requesting binary forward to $lhost($local)"
            set to [split $lhost($local) :]
            if {[llength $to] == 2} {
                #puts "$to"
                set ei [Event "Tunnel to peer at $lhost($local)"]
                set remote [route $local {*}$to 0]
                if {$remote ne ""} {
                    set first($remote) $first_part
                    #puts "Setup binary forward to $to"
                    return
                }
            }
        }

        close $local
        return
    }

    fconfigure $local -buffering line -translation auto
    if {[eof $local] || [catch {gets $local line}]} {
        close $local
        return
    } else {

        set line $first_part$line

        dlog $line

        if {$line eq ""} {
            return
        }

        if {[string match "CONNECT *" $line]} {
            set verb CONNECT
        } elseif {[string match "GET *" $line]} {
            set verb GET
        } else {
            dlog "Unknown request"
            puts "`$lhost($local)` UNKNOWN: `$line`"
            close $local
            return
        }


        #look for url
        set url "[lindex [split $line { }] 1]"
        dlog $url


        if {$url eq {}} {
            close $local
            return
        }

        if {$verb eq "CONNECT"} {
            set lhost($local) $url
            fconfigure $local -buffering none -blocking 0
            set l [read $local]
            set reply "HTTP/1.0 200 Connection Established\nStartTime: [clock format [clock seconds] -format %H:%M:%S]\nConnection: close\n\n"
            puts -nonewline $local $reply
            flush $local
            dlog "Flushing CONNECT"
            return
        }

        if {$lhost($local) ne "" && ![string match "http*" $url]} {
            set url "http://$lhost($local)$url"
        }

        set parse [regexp -nocase {http://([-a-z0-9.]+):?([0-9]+)?(.+)} $url _ host port rest]
        if {!$parse} {
            if {[regexp -nocase {https://([-a-z0-9.]+):?([0-9]+)?(.+)} $url _ host port rest]} {
                dlog_set [Event "($host) HTTPS not supported"]
            } else {
                dlog_set [Event "Couldn't parse $url"]
            }
            close $local
            return
        }
        if {![info exists port] || $port eq {}} {set port 80}
        dlog "Forwarding to $host:$port"


        set fake $rest


        if {[string first info_hash= $fake] > -1} {

            if {[info exists ::hosts($host:$port)]} {
                incr ::hosts($host:$port)
            } else {
                set ::hosts($host:$port) 1
            }

            #Extract some query string parameters
            set types {downloaded uploaded left info_hash event}
            foreach type $types {
                set $type {}
                if {[regexp $type=(\[^&\]+) $fake match $type]} {
                }
            }

            set ::hash_lookup($log_num) $info_hash

            if {$downloaded ne {} && $uploaded ne {} && $left ne {}} {
                #Have the basic tracker update parameters - mess with them.

                #This sets actual_previous_down, actual_previous_down_diff, etc
                stats_actual $info_hash $event $downloaded $uploaded $left


                set reported_previous_down 0
                set reported_previous_up 0
                set reported_previous_left 0
                set elapsed_time 0

                if {$event ne {started}} {
                    if {[info exists ::reported_last($info_hash)]} {
                            lassign $::reported_last($info_hash) reported_previous_down reported_previous_up reported_previous_left
                    }
                    if {[info exists ::reported_last_time($info_hash)]} {
                        set elapsed_time [expr {[clock seconds] - $::reported_last_time($info_hash)}]
                    }
                }


                set post "$host:$port down/up from "
                append post "[FormatData $downloaded]/[FormatData $uploaded] to "

                if {$::settings(no_download)} {

                    lassign $::actual_first($info_hash) d u l
                    dlog "Loaded first stats: $d $u $l"

                    set downloaded 0
                    set left $l

                    if {$::settings(seed)} {
                        set left 0
                    }

                    if {$event eq {completed}} {
                        dlog "Blocking completed event"

                        set com event=completed
                        if {[string match -nocase *&$com* $fake]} {
                            set fake [string map -nocase [list &$com {}] $fake]
                        } else {
                            set fake [string map -nocase [list $com& {}] $fake]
                        }
                    }
                }


                set last_peers 0
                if {[info exists ::response($info_hash,incomplete)]} {
                    set last_peers $::response($info_hash,incomplete)
                }

                dlog "Last number of leechers was: $last_peers"

                if {$last_peers >= $::settings(min_peers)} {

                    set down_ratio [expr {$::settings(updown_ratio_b) + rand() * ($::settings(updown_ratio_a) - $::settings(updown_ratio_b))}]
                    set up_ratio [expr {$::settings(upup_ratio_b) + rand() * ($::settings(upup_ratio_a) - $::settings(upup_ratio_b))}]

                    dlog "Previous upload was: $reported_previous_up"
                    dlog "Actual download was: $actual_previous_down_diff"
                    dlog "Actual upload was: $actual_previous_up_diff"
                    dlog "Random download ratio is: $down_ratio"
                    dlog "Random upload ratio is: $up_ratio"

                    set uploaded [expr {$reported_previous_up + $actual_previous_up_diff}]
                    set uploaded [expr {$uploaded + ($down_ratio * $actual_previous_down_diff)]
                    set uploaded [expr {$uploaded + ($up_ratio * $actual_previous_up_diff)}]

                    dlog "Time from last report was: $elapsed_time"
                    dlog "Rolling for boost."

                    if {rand() * 100 < $::settings(boost_chance)} {
                        set boost [expr {$::settings(boost) * 1024 * $elapsed_time * rand()}]
                        dlog "Adding in extra boost of: $boost"
                        set uploaded [expr {$uploaded + $boost}]
                    }


                } else {

                    dlog "Didn't meet peer count - setting in actual upload."
                    dlog "Actual upload was: $actual_previous_up_diff"
                    set uploaded [expr {$reported_previous_up + $actual_previous_up_diff}]

                }

                dlog "Setting uploaded to $uploaded"


                if {$event ne {started}} {
                    if {$uploaded < $reported_previous_up} {
                        dlog_set [Event "($host) LOGIC ERROR - SKIPPING TO AVOID DETECTION"]
                        foreach e [list actual_previous_down actual_previous_up actual_previous_down_diff actual_previous_up_diff \
                            reported_previous_down reported_previous_up reported_previous_left uploaded downloaded left] {
                                dlog "DEBUG $e [set $e]"
                            }
                            close $local
                            return
                    }
                }

                set uploaded [format %.0f $uploaded]

                #splice back in uploaded, downloaded, left
                foreach type [lrange $types 0 2] {
                    set fake [regsub $type=(\[^&\]+) $fake $type=[set $type]]
                }

                append post "[FormatData $downloaded]/[FormatData $uploaded]"

                if {$event ne {}} {
                    append post " ($event)"
                }

                dlog $post
                set ei [Event $post]
                dlog "Event idx $ei"
                dlog_set $ei

                stats_reported $info_hash $event $downloaded $uploaded $left
                dlog "Changed request from:\n$rest\nto\n$fake"

            } else {
                #Has infohash, but not downloaded, uploaded, etc
                #Probably scrape, which we don't really care about.
                dlog "Forwarding non-announce traffic."
                set ei [Event "$host:$port Non-announce traffic."]
                dlog_set $ei
            }


        } else {
            #No infohash
            if {$::settings(only_tracker)} {
                dlog "Blocking non-tracker traffic."
                set ei [Event "$host:$port Blocked non-tracker traffic."]
                dlog_set $ei
                close $local
                return
            } else {
                dlog "Forwarding non-tracker traffic."
                set ei [Event "$host:$port Forwarding non-tracker traffic."]
                dlog_set $ei
            }
        }



        set remote [route $local $host $port $log_num]
        if {$remote ne ""} {
            set first($remote) "GET $fake HTTP/1.1\r\n"
        }

    }
}


proc route {local host port log_num} {
    upvar 1 ei ei
    global rinfo linfo

    dlog "Opening socket $host:$port"
    set err {}
    set e [catch {set remote [socket -async $host $port]} err]
    if {$e} {
        dlog "Couldn't open socket to remote host."
        dlog $err
        EventAppend $ei " (error)"
        close $local
        return ""
    }

    fconfigure $remote -buffering none -blocking 0 -encoding binary -translation binary
    fileevent $remote readable [list read_remote $log_num $ei $local $remote]

    fconfigure $local -buffering none -blocking 0 -encoding binary -translation binary
    fileevent $local readable [list read_local $log_num $ei $local $remote]

    set rinfo($remote) "$host:$port"

    return $remote
}



proc read_remote {log_num ei local remote} {
    global rinfo linfo
    if {[eof $remote] || [catch {set l [read $remote]}]} {
        dlog "Closed remote - $local <-> $remote - $linfo($local) <-> $rinfo($remote)"
        close $remote
        close $local
        return
    }
    if {$l eq {}} return
    dlog "Sending [string length $l] bytes - $local <- $remote - $linfo($local) <- $rinfo($remote)"

    catch {puts -nonewline $local $l}
    catch {flush $local}
    dlog "read $rinfo($remote)\n$l\n"


    if {[info exists ::hash_lookup($log_num)]} {
        set hash $::hash_lookup($log_num)
        #example response:
        #....8:completei89e10:incompletei2e8:intervali1800e....
        foreach t {complete incomplete interval} {
            set $t 0
            set rg "[string length $t]:[set t]i(\[0-9\]+)e"
            if {[regexp $rg $l _ val]} {
                set $t $val
            }
            set ::response($hash,$t) [set $t]
        }

        dlog "Appending to event idx $ei"
        if {$complete != 0 || $incomplete != 0 || $interval != 0} {
            set peers " ($complete/$incomplete, [FormatElapsed $interval])"
            dlog "Found peer count: $peers"
            EventAppend $ei $peers
        } else {
            set fr {}
            if {[regexp {14:failure reason([0-9]+):} $l _ frlen]} {
                if {[regexp "14:failure reason$frlen:(.{$frlen})" $l _ fr]} {
                    dlog "Failure reason: $fr"
                    EventAppend $ei " (fail: $fr)"
                } else {
                    dlog "Bad failure reason"
                    EventAppend $ei " (bad failure reason)"
                }
            }
        }
    }

}


proc read_local {log_num ei local remote} {
    global rinfo linfo first
    if {[eof $local] || [catch {set l [read $local]}]} {
        dlog "Closed local - $local <-> $remote - $linfo($local) <-> $rinfo($remote)"
        close $local
        close $remote
        return
    }
    if {$l eq {}} return
    if {[info exists first($remote)]} {
        set l "$first($remote)$l"
        unset first($remote)
    }

    #Some programs put 127.0.0.1 in the Host - can't have that.
    lassign [split $rinfo($remote) :] host port
    if {$port != 80} {
        set host $host:$port
    }
    set l [regsub "Host: 127.0.0.1:$::settings(listen_port)" $l "Host: $host"]


    dlog "Sending [string length $l] bytes - $local -> $remote - $linfo($local) -> $rinfo($remote)"
    catch {puts -nonewline $remote $l}
    catch {flush $remote}
    dlog "sent $rinfo($remote)\n$l\n"
}


proc listen args {
    global listen_socket

    if {$::settings(listen_port) eq {}} return
    if {![string is integer $::settings(listen_port)]} return


    if {[info exists listen_socket] && $listen_socket ne {}} {
        close $listen_socket
    }

    set listen_socket [socket -server prox $::settings(listen_port)]
    puts "Listening with $listen_socket on $::settings(listen_port)"
    Event "Listening on 127.0.0.1:$::settings(listen_port)"
}
