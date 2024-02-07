build-ex:
	iverilog -g2012 barrelshifter_rtl.sv barrelshifter_tb.sv -o barrelshifter-ex.out

run-ex: build-ex
	vvp barrelshifter-ex.out

build:
	iverilog -g2012 barrelshifter_student.sv barrelshifter_tb.sv -o barrelshifter.out

run: build
	vvp barrelshifter.out

compare:
	bash -c 'diff <(make run-ex | tail -n +4 | head -n -2) <(make run | tail -n +4 | head -n -2)'