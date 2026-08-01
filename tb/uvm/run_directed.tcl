# Corre axi4_directed_test como proceso Vivado fresco (evita el bug de
# parseo de argumentos de xsim al reusar una sesion de shell/Tcl Shell).
exec xsim rolC_snapshot -R -testplusarg {UVM_TESTNAME=axi4_directed_test} -log directed_test.log