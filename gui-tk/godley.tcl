#  @copyright Steve Keen 2012
#  @author Russell Standish
#  This file is part of Minsky.
#
#  Minsky is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Minsky is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Minsky.  If not, see <http://www.gnu.org/licenses/>.
#


# Godley table

set fp [open "$minskyHome/accountingRules" r]
set accountingRules [read $fp]
close $fp

# set up accounting rules (and their inverse)
foreach {account_type line rule1DRCR rule1sign rule1color rule2DRCR rule2sign rule2color} $accountingRules {
    array set $account_type [list $rule1sign $rule1DRCR $rule2sign $rule2DRCR $rule1DRCR $rule1sign $rule2DRCR $rule2sign]
    array set color${account_type} [list $rule1sign $rule1color $rule2sign $rule2color $rule1DRCR $rule1color $rule2DRCR $rule2color]
}

proc accountingRules {accountType prefix} {
    if {$accountType == "noAssetClass"} { set accountType "SingleEntry" }
    upvar #0 $accountType account_type
    return $account_type($prefix)
}

proc accountingColor {accountType prefix} {
    if {$accountType == "noAssetClass"} { set accountType "SingleEntry" }
    upvar #0 color$accountType account_type
    return $account_type($prefix)
}

proc createGodleyWindow {id} {
    global globals preferences
    toplevel .godley$id 
    wm title .godley$id "Godley Table"
    wm withdraw .godley$id

    set globals(updateGodleyLaunched$id) 0

    set t .godley$id.table
    table $t \
        -rows 1 \
        -cols 1 \
        -colwidth 20 \
        -titlerows 0 \
        -titlecols 0 \
        -yscrollcommand ".godley$id.sy set" \
        -xscrollcommand ".godley$id.sx set" \
        -coltagcommand colorize \
        -flashmode off \
        -selectmode extended \
        -ellipsis on \
        -width 20 -height 20 \
        -colstretch all \
        -rowstretch all \
        -multiline 0

    bind $t <Return> {%W activate {}}

    #make column 0 narrower
    $t width 0 15

    # make column 1 wider
    $t width 1 30

    $t configure -usecommand 1 -command "setGetCell $id %r %c %i %s %W" 

    $t tag configure black -foreground black
    $t tag configure red -foreground red

    # required to make this behave on Windows.            
    $t tag configure active -foreground black    

    entry .godley$id.topbar -justify center -background CadetBlue2
    bind .godley$id.topbar <Leave> "updateGodleyTitle $id"
    bind .godley$id.topbar <Key-Return> "updateGodleyTitle $id"

    scrollbar .godley$id.sy -command [list $t yview]
    scrollbar .godley$id.sx -command [list $t xview] -orient horizontal

    pack .godley$id.topbar -fill x
    pack .godley$id.sy -side right -fill y
    pack .godley$id.sx -side bottom -fill x
    pack .godley$id.table -fill both 

    menu .godley$id.cellMenu
    .godley$id.cellMenu add command -label Cut -command "cutCurrCell $id"
    .godley$id.cellMenu add command -label Copy -command "copyCurrCell $id"
    .godley$id.cellMenu add command -label Paste -command "pasteCurrCell $id"

    bind .godley$id  <<contextMenu>> "postEditMenu $id %x %y %X %Y"
    
}

proc postEditMenu {id x y X Y} {
    .godley$id.table activate @$x,$y
    tk_popup .godley$id.cellMenu $X $Y
}

proc cutCurrCell {id} {
    copyCurrCell $id
    .godley$id.table curvalue {}
}

proc copyCurrCell {id} {
    clipboard clear
    clipboard append [.godley$id.table curvalue]
}

proc pasteCurrCell {id} {
    .godley$id.table curvalue [clipboard get]
}

proc parse_input {input p v} {
    upvar $p prefix
    upvar $v varName
    
    if {[string trim $input] == ""} {
        set prefix ""
        set varName ""
        return 1
    }

    # regexp accepts input of the form "?DR|CR|-? VarName" or ""
    # eg   "var"   "-var"    "dr var"   "DR var"  ""

    set retval [regexp {^\s*([cCdD][rR])\s+(.*)} $input matchstr prefix varName]

    if {$retval} {
        set prefix [string toupper $prefix]
        set retval [regexp {^[^\s=-][^=]*} $varName]
    } else {
        # try looking for a sign
        set retval [regexp {^\s*([-])-*\s*([^\s=-][^=]*)} $input matchstr prefix varName]
        if {!$retval} {
            set retval [regexp {^\s*([^-=][^=]*)} $input matchstr varName]
            set prefix ""
        }
    } 

    if {$retval} {
        set varName [string trim $varName]
    } else {
        set prefix ""
        set varName ""
    }     

    return $retval
}



proc updateGodleyTitle {id} {
    if {[$id.table.title]!=[.godley$id.topbar get]} {
        $id.table.title [.godley$id.topbar get]
        updateGodley $id
    }
}

proc setGetCell {id r c i s w} {
    set r [setGetCell_ $id $r $c $i $s $w]
    return $r
}

proc setGetCell_ {id r c i s w} {
    global preferences

    if {$r>0 && $c>0} {
        set row [expr $r-1]
        set col [expr $c-1]
            # allow for asset class row
            incr row -1
            if {$row==-1} return "";
            # TODO: compute row sum here
            if {$col==[$id.table.cols]} {
                if {$row>0} {
                    return [$id.table.rowSum $row]
                } else {
                    # don't sum column labels
                    return "Row Sum"
                }
            }
        if {$i && $id>=0} {
	    set varName $s
	    if {$row>0 && $col>0} {
                set account_type [$id.table.assetClass $col]
                if {$account_type == "noAssetClass"} return

	# parse_input accepts input of the form "?DR|CR|-? VarName"
	# where VarName cannot begin with DR or CR
	# eg   "var"   "-var"    "dr var"   "DR var"

		if {![parse_input $s prefix varName]} {return}

		switch $prefix {
		   "" {}
		   CR - DR {
		       if {"-" == [accountingRules $account_type $prefix]} {
			    set varName "-$varName"
		       }
		   }
		   - {
			    set varName "-$varName"
		   }
		   default { error "invalid prefix $prefix" }
		}
	    }
            $id.setCell $row $col $varName
            #check consistency
            if [catch $id.update errormsg] {
                bgerror $errormsg
                $id.setCell $row $col ""
            }
            whenIdleUpdateGodley $id
        } else {
            set s [$id.table.getCell $row $col]
	    if {$row>0 && $col>0} {
                set account_type [$id.table.assetClass $col]
                if {$account_type == "noAssetClass"} {
                    return "Asset Class Not Set"
                }
		if [string length $s] {
			set account_type [$id.table.assetClass $col]
			set show $s

			# use parse_input to format output for consistency
			set key $s
			set prefix ""
			parse_input $s prefix key

			if {$prefix == "-"} {
			   set sign -
			} else {
			   set sign +
			}
			$w tag cell [accountingColor $account_type $sign] "$r,$c"
			# if $key is a number, just pass it on
			# otherwise apply accounting format
			if {![string is double $key]} {
			    set val ""
			    switch $preferences(godleyDisplayStyle) {
				"DRCR" {
				    if {[t]>0 && $preferences(godleyDisplay)} {
				       set val ""
				       catch {
					   value.get $key
					   set val [value.value]
				       }
				       set val " = $val"
				    }
				    set DRCR [accountingRules $account_type $sign]
				    set show "$DRCR $key$val"
				}
				"sign" {
				    if {[t]>0 && $preferences(godleyDisplay)} {
				       set val ""
				       catch {
					   value.get $key
					   set val [value.value]
				       }
					switch $sign {
					    - { if {[catch {
						    set val "= [expr -($val)]"
						}]} {
						    set val "= $val"
						}
					       }
					    default {set val "= $val"}
					}
				    }
				    set show "$s $val"
				}
				default { error "unknown display style $preferences(godleyDisplayStyle)"}
			    }
			}
			return $show
		     } else {
			return " "
		     }
		} else {
		    return $s
		}
        }
    }
}

proc openGodley {} {
    set id [TCLItem]
    if {![winfo exists .godley$id]} {createGodleyWindow $id}
    deiconify .godley$id
    raise .godley$id .
    updateGodley $id
}

proc addRow {id r} {
    $id.table.insertRow $r
    # if we don't remove activation, sometimes the cell content is not correctly updated
    .godley$id.table activate 0,0
    updateGodley $id
}

proc delRow {id r} {
    $id.deleteRow $r
    .godley$id.table activate 0,0
    updateGodley $id
}

proc addCol {id c} {
    $id.table.insertCol $c
    .godley$id.table activate 0,0
    updateGodley $id
}

proc delCol {id c} {
    $id.table.deleteCol $c
    .godley$id.table activate 0,0
    updateGodley $id
}
    
proc moveRow {id row n} {
    $id.table.moveRow [expr $row-1] $n
    .godley$id.table activate 0,0
    updateGodley $id
}

proc moveCol {id col n} {
    $id.table.moveCol [expr $col-1] $n
    .godley$id.table activate 0,0
    updateGodley $id
}
  
# return row or column index of cell over which mouse is located
proc currCell {id rowOrCol} {
    return [.godley$id.table index @[get_pointer_x .godley$id.table],[get_pointer_y .godley$id.table] $rowOrCol]
}

proc moveCell {id} {
    global cellMove
    if {[array size cellMove]==0} {
        set cellMove(row) [expr [currCell $id row]-1-[$id.table.doubleEntryCompliant]]
        set cellMove(col) [expr [currCell $id col]-1]
        if {$cellMove(row)<1 || $cellMove(col)<1} {
# outside movable cells
            array unset cellMove
            return 
        }
	if {[tk windowingsystem]=="aqua"} {
	    .godley$id.table configure -cursor copyarrow
	} else {
	    .godley$id.table configure -cursor exchange
	}
        bind .godley$id <ButtonRelease> "finishMoveCell $id"
    }
    .godley$id.table activate @[get_pointer_x .godley$id.table],[get_pointer_y .godley$id.table]
}

proc finishMoveCell {id} {
    global cellMove
    if {[array size cellMove]>0} {
        set destRow [expr [currCell $id row]-1-[$id.table.doubleEntryCompliant]]
        set destCol [expr [currCell $id col]-1]
        if {$destRow==$cellMove(row) && $destCol==$cellMove(col)} {
            .godley$id.table activate @[get_pointer_x .godley$id.table],[get_pointer_y .godley$id.table]
        } elseif {$destRow>0 && $destCol>0} {
            $id.moveCell $cellMove(row) $cellMove(col) $destRow $destCol
            updateGodley $id
        }
    }
    array unset cellMove
    .godley$id.table configure -cursor xterm
    bind .godley$id <ButtonRelease> ""
}

proc updateGodleys {} {
  global globals
    foreach win [lsearch -inline -all [winfo children .] .godley*] {
        updateGodley [regsub {.godley([:digit:]*)} $win "\1"]
    }
}

proc updateGodleysDisplay {} {
    foreach w [winfo children .] {
        if [regexp "\.godley(\[0-9\]*)" $w match id] {
            updateGodleyDisplay $id
        }
    }
}

# sets a when-idle job to update the godley table, to prevent the table being updated too often during rapid fire requests
proc updateGodley {id} {
    global globals
    if {$id < 0 || ![winfo exists .godley$id]} {return}
    if {!$globals(updateGodleyLaunched$id)} {
        set $globals(updateGodleyLaunched$id) 1
        after idle whenIdleUpdateGodley $id
    }
}

proc columnVarTrace {id col varName args} {
    global $varName
    # putting a catch here allows us to present a cleaner error
    # message to the user, as this proc can be called by other
    # operations
    $id.setCell 0 $col [set $varName]
    if [catch {$id.update} msg] {
        bgerror $msg
        $id.setCell 0 $col ""
    }
    updateGodleyDisplay $id
}

proc whenIdleUpdateGodley {id} {
    if {![winfo exists .godley$id]} return

    doPushHistory 0
    pushFlags
    whenIdleUpdateGodleyDisplay $id

    # delete row/col buttons
    foreach c [info commands .godley$id.???Buttons{*}] {destroy $c}
    # delete asset class dropdowns
    foreach c [info commands .godley$id.assetClass{*}] {destroy $c}
    # delete column variable dropdowns
    foreach c [info commands .godley$id.stockVarName{*}] {destroy $c}

    # bind mouse motion handlers to each cell
    bind .godley$id.table <B1-Motion> "moveCell $id"

    # put the double entry book keeping mode button in top left corner
#    .godley$id.table window configure 0,0 -window .godley$id.doubleEntryMode

    global minskyHome tcl_platform
    image create photo leftArrow -file $minskyHome/icons/leftArrow.gif 
    image create photo rightArrow -file $minskyHome/icons/rightArrow.gif 
    image create photo upArrow -file $minskyHome/icons/upArrow.gif 
    image create photo downArrow -file $minskyHome/icons/downArrow.gif 
    set bw 20
    set bh 20
    # en-dashes don't appear to display properly on windows
    if {$tcl_platform(platform)=="windows"} {
        set minus "-"
    } else {
        set minus "–"
    }

    for {set r 1} {$r<[expr [$id.table.rows]+1]} {incr r} {
        set ro [expr $r+[$id.table.doubleEntryCompliant]]
        frame .godley$id.rowButtons{$r}
        button .godley$id.rowButtons{$r}.add -foreground green -text "+" \
            -command "addRow $id $r"
        pack .godley$id.rowButtons{$r}.add -side left
        if {$r>1} {
            button .godley$id.rowButtons{$r}.del -foreground red -text $minus \
                -command "delRow $id $r"
            pack .godley$id.rowButtons{$r}.del -side left
            if {$r>2} {
                button .godley$id.rowButtons{$r}.up -image upArrow \
                    -width $bw -height $bh \
                    -command "moveRow $id $r -1"
                pack .godley$id.rowButtons{$r}.up -side left
            }
            button .godley$id.rowButtons{$r}.down -image downArrow \
                -width $bw -height $bh \
                -command "moveRow $id $r 1"
            pack .godley$id.rowButtons{$r}.down -side left
        }
      
        .godley$id.table window configure $ro,0 -window .godley$id.rowButtons{$r}
            

    }
    for {set c 1} {$c<[expr [$id.table.cols]+1]} {incr c} {
        frame .godley$id.colButtons{$c}
        button .godley$id.colButtons{$c}.add -foreground green -text "+"  \
            -command "addCol $id $c"
        pack .godley$id.colButtons{$c}.add  -side left
        if {$c>1} {
            button .godley$id.colButtons{$c}.del -foreground red -text $minus \
                -command "delCol $id $c"
            pack .godley$id.colButtons{$c}.del  -side left
            if {$c>2} {
                button .godley$id.colButtons{$c}.left -image leftArrow \
                    -width $bw -height $bh \
                    -command "moveCol $id $c -1"
                pack .godley$id.colButtons{$c}.left -side left
            }
            button .godley$id.colButtons{$c}.right -image rightArrow \
                -width $bw -height $bh \
                -command "moveCol $id $c 1"
            pack .godley$id.colButtons{$c}.right -side left
        }
        

        .godley$id.table window configure 0,$c -window .godley$id.colButtons{$c}

        if {$c>1 && [$id.table.doubleEntryCompliant]} {
            # C++ table column offset by one wrt TkTable columns
            set col [expr $c-1]
            menubutton .godley$id.assetClass{$c} -menu .godley$id.assetClass{$c}.menu\
                -text [$id.table.assetClass $col] -relief raised
            menu .godley$id.assetClass{$c}.menu
            # create a drop menu on the stock variable names to allow
            # population by available names
            foreach assetClass [assetClasses] {
                .godley$id.assetClass{$c}.menu add command -label $assetClass \
                    -command "
                      $id.table.assetClass $col $assetClass
                      updateGodley $id
                    "
            }
           .godley$id.table window configure 1,$c -window .godley$id.assetClass{$c}
            global godley$id.stockVarName{$c}
            set godley$id.stockVarName{$c} [setGetCell $id 2 $c 0 {} .godley$id.table]
            ttk::combobox .godley$id.stockVarName{$c} -textvariable godley$id.stockVarName{$c} \
                -values [matchingTableColumns $id [$id.table.assetClass $col] ]
            trace add variable godley$id.stockVarName{$c} write "columnVarTrace $id $col"
            .godley$id.table window configure 2,$c -window .godley$id.stockVarName{$c}
        }
    }

    $id.update
    global updateGodleyLaunched
    set updateGodleyLaunched 0
    # FIXME: this fails: updateCanvas
    update
    doPushHistory 1
    popFlags
}


proc updateGodleyDisplay {id} {
    global globals
    if {$id < 0 || ![winfo exists .godley$id]} {return}
    if {!$globals(updateGodleyLaunched$id)} {
        set $globals(updateGodleyLaunched$id) 1
        after idle whenIdleUpdateGodleyDisplay $id
    }
}

proc whenIdleUpdateGodleyDisplay {id} {
    if {![winfo exists .godley$id]} return
    pushFlags
    .godley$id.table clear cache
    
    set nrows [expr [$id.table.rows]+1]
    set ncols [expr [$id.table.cols]+1]
    if [$id.table.doubleEntryCompliant] {
        incr nrows
        incr ncols
    }

    # remove any selection - ticket 88
    .godley$id.table selection clear all
    .godley$id.table activate -1,-1

    wm title .godley$id "Godley Table: [$id.table.title]"
    .godley$id.topbar delete 0 end
    if {[$id.table.title]==""} {
        .godley$id.topbar insert 0 "Godley$id"
    } else {
        .godley$id.topbar insert 0 [$id.table.title]
    }
    if {[.godley$id.table cget -rows]!=$nrows || [.godley$id.table cget -cols]!=$ncols} {
        .godley$id.table configure -rows $nrows -cols $ncols
        # ensure buttons etc are drawn correctly
        after idle whenIdleUpdateGodley $id
    }
    popFlags
}

