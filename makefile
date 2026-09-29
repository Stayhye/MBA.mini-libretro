###########################################################################
#
#   makefile
#
#   Core makefile for building MAME and derivatives (PS2 Optimized)
#
#   Copyright (c) Nicola Salmoria and the MAME Team.
#   Visit http://mamedev.org for licensing and usage restrictions.
#
###########################################################################

NATIVE := 0
ALIGNED = 0
MDEBUG = 0
PTR64 = 0
BIGENDIAN = 0

NEOGEO_BIOS = 0

# system platform
UNAME = $(shell uname -a)

ifeq ($(platform),)
    platform = unix
    system_platform = unix
    ifeq ($(UNAME),)
     platform = win
     EXE_EXT = .exe
     system_platform = win
    else ifneq ($(findstring MINGW,$(UNAME)),)
     platform = win
     system_platform = win
    else ifneq ($(findstring Darwin,$(UNAME)),)
     platform = osx
     system_platform = osx
    else ifneq ($(findstring win,$(UNAME)),)
     platform = win
    endif
endif

UNAME := $(shell uname -m)

ifeq ($(firstword $(filter x86_64,$(UNAME))),x86_64)
    PTR64 = 1
endif
ifeq ($(firstword $(filter amd64,$(UNAME))),amd64)
    PTR64 = 1
endif
ifneq (,$(findstring mingw64-w64,$(PATH)))
    PTR64 = 1
endif
ifeq ($(firstword $(filter ppc64,$(UNAME))),ppc64)
    PTR64 = 1
endif
ifeq ($(firstword $(filter aarch64,$(UNAME))),aarch64)
    PTR64 = 1
endif
ifneq (,$(findstring Power,$(UNAME)))
    BIGENDIAN = 1
endif
ifneq (,$(findstring ppc,$(UNAME)))
    BIGENDIAN = 1
endif

DEFS = -DCRLF=2 -DDISABLE_MIDI=1
ARFLAGS = -cr
BUILD_MIDILIB = 0

#-------------------------------------------------
# compile flags
#-------------------------------------------------

CCOMFLAGS = -DDISABLE_MIDI
CONLYFLAGS =
COBJFLAGS =
CPPONLYFLAGS =

LDFLAGS =
LDFLAGSEMULATOR =

TARGET_NAME ?= mbamini
fpic := 
EXE = 
LIBS = 
CORE_DIR = .

CCOMFLAGS += -D__LIBRETRO__

OPTFLAG ?= 0
VRENDER ?= soft
HW_RENDER ?= 0

# UNIX
ifeq ($(platform), unix)
    TARGETLIB := $(TARGET_NAME)_libretro.so
    TARGETOS = linux
    fpic = -fPIC
    SHARED := -shared -Wl,--version-script=src/osd/retro/link.T
    LDFLAGS += $(SHARED)
    CC = gcc
    CXX = g++
    AR = ar
    LD = g++
    CCOMFLAGS += -fno-common -fno-merge-constants -fsingle-precision-constant -ffast-math
    LIBS += -lstdc++ -lpthread
    ALIGNED = 1

# PS2 (Exact working compilation flags preserved)
else ifeq ($(platform), ps2)
    PTR64 = 0
    TARGET_NAME = mbamini
    TARGETLIB := $(TARGET_NAME)_libretro_$(platform).a
    CC = mips64r5900el-ps2-elf-g++
    CXX = mips64r5900el-ps2-elf-g++
    AR = mips64r5900el-ps2-elf-ar
    CFLAGS += -O3 -march=r5900 -mtune=r5900 -G0 -ffast-math -DPS2 -DABGR1555 
    CXXFLAGS += -O3 -march=r5900 -mtune=r5900 -G0 -ffast-math -DPS2 -DABGR1555 
    CPPONLYFLAGS += -std=gnu++98 -x c++ -fexceptions -Wno-template-id-cdtor 
    LDFLAGS += -L$(PS2DEV)/ps2sdk/ports/lib -L$(PS2DEV)/ps2sdk/ee/lib
    STATIC_LINKING=1
    STATIC_LINKING_LINK=1
    PLATFORM_DEFINES := -DPS2 -DVIDEO_ABGR1555 -x c++
    FRONTEND_SUPPORTS_RGB565 = 0

# Default Windows / Fallback
else
    TARGETLIB := $(TARGET_NAME)_libretro.dll
    TARGETOS = win32
    CC = gcc
    CXX = g++
    LD = g++
    SHARED := -shared -static-libgcc -static-libstdc++
    LDFLAGS += $(SHARED)
    EXE = .exe
endif

GIT_VERSION ?= "$(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
    CCOMFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

ifeq ($(ALIGNED), 1)
    CCOMFLAGS += -DALIGN_INTS -DALIGN_SHORTS
endif

CCOMFLAGS += $(fpic)
LDFLAGS   += $(fpic)

###########################################################################
#################     BEGIN USER-CONFIGURABLE OPTIONS     #################
###########################################################################

TARGET = mame
SUBTARGET = mame
NOWERROR = 1
OSD = retro
CROSS_BUILD_OSD = retro
OPTIMIZE = 3

MD = mkdir -p
RM = rm -f
OBJDUMP = objdump

SUFFIX64 =
SUFFIXDEBUG =
SUFFIXPROFILE =

ifeq ($(PTR64), 1)
    SUFFIX64 = 64
endif

EMULATOR = $(TARGETLIB)

OBJ = obj/$(PREFIX)$(OSD)$(SUFFIX)$(SUFFIX64)$(SUFFIXDEBUG)$(SUFFIXPROFILE)

DEFS += -DINLINE="static inline" -DFLAC__NO_DLL

ifeq ($(BIGENDIAN), 1)
    DEFS += -DMSB_FIRST
endif

# Only set default standards if not compiling for PS2
ifneq ($(platform), ps2)
    CONLYFLAGS += -std=gnu89
    CPPONLYFLAGS += -x c++ -std=gnu++98
endif

CCOMFLAGS += -pipe

ifeq ($(MDEBUG), 1)
    CCOMFLAGS += -O0 -g -DMAME_DEBUG
else
    CCOMFLAGS += -O$(OPTIMIZE) -DNDEBUG
endif

ifneq ($(OPTIMIZE), 0)
    CCOMFLAGS += -fno-strict-aliasing
endif

CCOMFLAGS += -Wall -Wundef -Wformat-security -Wwrite-strings -Wno-sign-compare -Wno-conversion

OBJDIRS = $(OBJ) $(OBJ)/$(TARGET) $(OBJ)/$(TARGET)/$(SUBTARGET)

default: maketree emulator

all: default

BUILDSRC = $(CORE_DIR)/src/build
BUILDOBJ = $(OBJ)/build
BUILDOUT = $(BUILDOBJ)

include makefile.common

CCOMFLAGS += $(INCFLAGS) -fno-delete-null-pointer-checks
CDEFS = $(DEFS)

#-------------------------------------------------
# primary targets
#-------------------------------------------------

emulator: maketree $(EMULATOR)

maketree: $(sort $(OBJDIRS))

clean:
	@echo Deleting object tree $(OBJ)...
	$(RM) -r obj/*
	@echo Deleting target $(TARGETLIB)...
	$(RM) $(TARGETLIB)

$(sort $(OBJDIRS)):
	@$(MD) $@

#-------------------------------------------------
# executable/archive targets
#-------------------------------------------------

ifeq ($(STATIC_LINKING),1)
$(EMULATOR): $(OBJECTS)
	@echo Archiving PS2 Static Library with Whole-Archive Support: $(TARGETLIB)
	@$(RM) $@
	@$(AR) $(ARFLAGS) $@ $^
else
$(EMULATOR): $(OBJECTS)
	@echo Linking: $(TARGETLIB)
	@$(CXX) $(LDFLAGS) -Wl,--whole-archive $^ -Wl,--no-whole-archive $(LIBS) -o $(TARGETLIB)
endif

#-------------------------------------------------
# generic compilation rules & sub-archive fix
#-------------------------------------------------

$(OBJ)/%.a:
	@$(MD) $(dir $@)
	@echo Archiving sub-library: $@
	@$(RM) $@
	@$(AR) $(ARFLAGS) $@ $^

$(OBJ)/%.o: $(CORE_DIR)/src/%.c | $(OSPREBUILD)
	@echo Compiling C: $<
	@$(CC) $(CDEFS) $(CCOMFLAGS) $(CONLYFLAGS) -c $< -o $@

$(OBJ)/%.o: $(CORE_DIR)/src/%.cpp | $(OSPREBUILD)
	@echo Compiling C++: $<
	@$(CXX) $(CDEFS) $(CCOMFLAGS) $(CPPONLYFLAGS) -c $< -o $@

$(OBJ)/%.o: $(CORE_DIR)/src/%.cc | $(OSPREBUILD)
	@echo Compiling C++: $<
	@$(CXX) $(CDEFS) $(CCOMFLAGS) $(CPPONLYFLAGS) -c $< -o $@

$(DRIVLISTOBJ): $(DRIVLISTSRC)
	@$(CC) $(CDEFS) $(CCOMFLAGS) $(CONLYFLAGS) -c $< -o $@