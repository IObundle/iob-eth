CORE := iob_eth
BOARD ?= AES-KU040-DB-G

#------------------------------------------------------------
# SETUP
#------------------------------------------------------------
include submodules/LIB/setup.mk


#------------------------------------------------------------
# DOCUMENT BUILD
#------------------------------------------------------------
doc-build: clean
	rm -rf ../$(CORE)_V*
	make setup && make -C ../$(CORE)_V*/ doc-build
	evince ../$(CORE)_V*/document/ug.pdf &

