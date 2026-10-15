
proc report_ip_status { current_ip_version original_ip_version upgrade_result current_part recommended_part } {

    set $current_ip_version [string trim $current_ip_version]
    set $current_part   [string trim $current_part]
    set $recommended_part   [string trim $recommended_part]
    set $original_ip_version    [string trim $original_ip_version]
    set $upgrade_result     [string trim $upgrade_result]

    if {$current_part != $recommended_part } {
        set IP_Status 3
        set Recommendation 1
        set Lock 1
        set Upgradable 0
        puts "current_part is different from recommended_part"
        return [list $IP_Status $Recommendation $Lock $Upgradable ]
    }

    set recommend_version "1.0.1"
    set IP_comparibiliy_table [list "1.0.0" "1.0.1" ]
    #puts "IP_comparibiliy_table is $IP_comparibiliy_table"
    set comparibiliy_result [lsearch -exact $IP_comparibiliy_table $current_ip_version]
    set recommend_version_list [split $recommend_version "."]
    set current_version_list [split $current_ip_version "."]

    if {$comparibiliy_result == -1} {
        set IP_Status 3
        set Recommendation 1
        set Lock 1
        set Upgradable 0
        puts "version is no include"
        return [list $IP_Status $Recommendation $Lock $Upgradable]      
    } 

    if {[lindex $recommend_version_list 0] != [lindex $current_version_list 0]} {
        set IP_Status 0
        set Recommendation 0
        set Lock 1
        set Upgradable 1
        return [list $IP_Status $Recommendation $Lock $Upgradable]              
    } elseif {[lindex $recommend_version_list 1] != [lindex $current_version_list 1]} {
        set IP_Status 1 
        set Recommendation 0
        set Lock 1
        set Upgradable 1
        return [list $IP_Status $Recommendation $Lock $Upgradable]
    } elseif {[lindex $recommend_version_list 2] != [lindex $current_version_list 2]} {
        set IP_Status 2
        set Recommendation 0
        set Lock 1
        set Upgradable 1
        return [list $IP_Status $Recommendation $Lock $Upgradable]            
    } elseif {$current_ip_version == $recommend_version} {
        set IP_Status 4
        set Recommendation 2
        set Lock 0
        set Upgradable 0
        return [list $IP_Status $Recommendation $Lock $Upgradable]             
    } else {
        set IP_Status 3
        set Recommendation 1
        set Lock 1
        set Upgradable 0            
        return [list $IP_Status $Recommendation $Lock $Upgradable]
    }
}

proc upgrade_ip	{ param_txt_path port_txt_path current_ip_version } {
    if {([file exists $param_txt_path] == 0) || ([file exists $port_txt_path] == 0)} {
        puts "param_txt_path or port_txt_path is not exists, upgrade exit"
        return 0
    } else {
        puts "param_txt_path and port_txt_path is exists !!!!"
        set param_con [open "$param_txt_path" r ] 
        set port_con  [open "$port_txt_path" r ]
    }
while {[gets $param_con line ]} {
    set input_file_line [split $line ":"]
    set input_file_line_index0 [lindex $input_file_line 0]
    set input_file_line_index1 [lindex $input_file_line 1]
    set input_file_line_index0 [string trim $input_file_line_index0]
    set input_file_line_index1 [string trim $input_file_line_index1]

    if {$input_file_line_index0 == "AXI_SUPPORTS_USER_SIGNALS"} {
        if {$input_file_line_index1 == 1} {
            set user_port_enable 1
            break
        } else {
            set user_port_enable 0
            break
        }
    }
}

close $param_con

set b_content ""

while {[gets $port_con line ] >= 0} {
    if {[string first "us_awuser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "us_awuser; 1"
        } else {
            set line "us_awuser; 0"
        }
    }

    if {[string first "us_wuser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "us_wuser; 1"
        } else {
            set line "us_wuser; 0"
        }
    }

    if {[string first "us_buser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "us_buser; 1"
        } else {
            set line "us_buser; 0"
        }
    }

    if {[string first "us_aruser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "us_aruser; 1"
        } else {
            set line "us_aruser; 0"
        }
    }

    if {[string first "us_ruser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "us_ruser; 1"
        } else {
            set line "us_ruser; 0"
        }
    }

    if {[string first "ds_awuser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "ds_awuser; 1"
        } else {
            set line "ds_awuser; 0"
        }
    }

    if {[string first "ds_wuser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "ds_wuser; 1"
        } else {
            set line "ds_wuser; 0"
        }
    }

    if {[string first "ds_buser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "ds_buser; 1"
        } else {
            set line "ds_buser; 0"
        }
    }

    if {[string first "ds_aruser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "ds_aruser; 1"
        } else {
            set line "ds_aruser; 0"
        }
    }

    if {[string first "ds_ruser" $line] != -1} {
        if {$user_port_enable == 1} {
            set line "ds_ruser; 1"
        } else {
            set line "ds_ruser; 0"
        }
    }

    append b_content "$line \n"
}

close $port_con

puts $b_content

set port_con [open "$port_txt_path" w]
puts -nonewline $port_con $b_content
close $port_con

return 1
    
}
