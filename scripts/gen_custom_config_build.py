import os


def gen_custom_config_build(py_params_dict):

    content = f"""
#This file was auto generated by gen_custom_config_build.py

#Mac address of pc interface connected to ethernet peripheral (based on board name)
$(if $(findstring sim,$(MAKECMDGOALS))$(SIMULATOR),$(eval BOARD=))
ifeq ($(BOARD),AES-KU040-DB-G)
RMAC_ADDR ?=989096c0632c
endif
ifeq ($(BOARD),CYCLONEV-GT-DK)
RMAC_ADDR ?=309c231e624b
endif
RMAC_ADDR ?=000000000000
export RMAC_ADDR
#Set correct environment if running on IObundle machines
ifneq ($(filter pudim-flan sericaia,$(shell hostname)),)
IOB_CONSOLE_PYTHON_ENV ?= /opt/pyeth3/bin/python
endif

### Set Ethernet environment variables
#Eth interface address of pc connected to ethernet peripheral (based on board name)
$(if $(findstring sim,$(MAKECMDGOALS))$(SIMULATOR),$(eval BOARD=))
ifeq ($(BOARD),AES-KU040-DB-G)
ETH_IF ?=eno1
endif
ifeq ($(BOARD),CYCLONEV-GT-DK)
ETH_IF ?= enp0s31f6
endif
# Set a MAC address for console (randomly generated)
RMAC_ADDR ?=88431eafa897
export RMAC_ADDR
#Set correct environment if running on IObundle machines
ifneq ($(filter feynman pudim-flan sericaia,$(shell hostname)),)
IOB_CONSOLE_PYTHON_ENV ?= /opt/pyeth3/bin/python
else
IOB_CONSOLE_PYTHON_ENV ?= ../../scripts/pyRawWrapper/pyRawWrapper
endif
"""

    file_path = os.path.join(py_params_dict["build_dir"], "custom_config_build.mk")
    with open(file_path, "w") as f:
        f.write(content)
        f.close()
