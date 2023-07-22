
.PHONY: all
all: sim

.PHONY: sim
sim: sim/Makefile
	make -C sim

.PHONY: view
view:
	gtkwave sim/dump.vcd -a sim/wave.sav &

sim/Makefile:
	cd sim && hdlmake -a && \
	echo '.PHONY: \044(VERILOG_OBJ)' >> Makefile 

.PHONY: clean
clean:
	make -C sim/ clean || true
	rm -f sim/Makefile sim/*.vvp sim/*.vcd
	
	