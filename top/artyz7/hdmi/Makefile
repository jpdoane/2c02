
.PHONY: all
all: synth

.PHONY: synth
synth: synth/Makefile
	make -C synth/

.PHONY: synth
bitfile: synth/Makefile
	make -C synth/ bitstream

synth/Makefile:
	cd synth && hdlmake -a

.PHONY: clean
clean:
	make -C synth/ clean || true
	rm -f synth/Makefile
	
	