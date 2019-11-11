.PHONY:all clean

all:
	gcc genwqe_gzip.c -o genwqe_gzip -lz

clean:
	rm genwqe_gzip
