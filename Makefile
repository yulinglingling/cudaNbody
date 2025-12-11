OUTPUTDIR := bin/

#-std=c++14
CFLAGS := -std=c++11 -fvisibility=hidden -lpthread

ifeq (,$(CONFIGURATION))
	CONFIGURATION := release
endif

ifeq (debug,$(CONFIGURATION))
CFLAGS += -g
else
CFLAGS += -O2 -fopenmp
endif

SOURCES := src/*.cpp src/nbody.cu
HEADERS := src/*.h

TARGETBIN := nbody-$(CONFIGURATION)

.SUFFIXES:
.PHONY: all clean

all: $(TARGETBIN)

$(TARGETBIN): $(SOURCES) $(HEADERS)
# 	$(CXX) -o $@ $(CFLAGS) $(SOURCES) 
	nvcc -std=c++11 -O2 -Xcompiler -fopenmp -o $@ $(SOURCES)

clean:
	rm -rf ./nbody-$(CONFIGURATION)

check:	default
	./checker.pl

FILES = src/*.cpp \
		src/*.h

handin.tar: $(FILES)
	tar cvf handin.tar $(FILES)
