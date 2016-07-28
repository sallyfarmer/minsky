#! /bin/sh

here=`pwd`
if test $? -ne 0; then exit 2; fi
tmp=/tmp/$$
mkdir $tmp
if test $? -ne 0; then exit 2; fi
cd $tmp
if test $? -ne 0; then exit 2; fi

fail()
{
    echo "FAILED" 1>&2
    cd $here
    chmod -R u+w $tmp
    rm -rf $tmp
    exit 1
}

pass()
{
    echo "PASSED" 1>&2
    cd $here
    chmod -R u+w $tmp
    rm -rf $tmp
    exit 0
}

trap "fail" 1 2 3 15

# insert ecolab script code here
# use \$ in place of $ to refer to variable contents
# exit 0 to indicate pass, and exit 1 to indicate failure
cat >input.tcl <<EOF
source $here/test/assert.tcl
proc afterMinskyStarted {} {
  minsky.load $here/examples/1Free.mky
  recentreCanvas
  updateCanvas
  foreach godley [items.#keys] {
    item.get \$godley
    if {[item.classType]=="GodleyIcon"} break
  }
  doubleMouseGodley \$godley 194 57
  doubleMouseGodley \$godley 78 62
  update
  # should open edit window
  assert {[winfo viewable .wiring.editVar]}
  .wiring.editVar.buttonBar.ok invoke
  assert {![winfo exists .wiring.editVar]}

  # double click on first variable
  foreach var [items.#keys] {
    item.get \$var
    switch -glob [item.classType] {
      "Variable*" break
    }
  }
  editItem \$var
  assert {[winfo viewable .wiring.editVar]} {varclick}
  .wiring.editVar.buttonBar.ok invoke
  assert {![winfo exists .wiring.editVar]} {varclick}


  resetEdited
  exit
}
EOF

$here/gui-tk/minsky input.tcl
if test $? -ne 0; then fail; fi

pass
