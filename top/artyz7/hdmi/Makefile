
.PHONY: all
all: synth

.PHONY: synth
synth: synth/Makefile
	make -C synth/

synth/Makefile:
	cd synth && hdlmake -a && \
	echo '.PHONY: \044(VERILOG_OBJ)' >> Makefile 

.PHONY: clean
clean:
	make -C synth/ clean || true
	rm -f synth/Makefile
	
	