# SPDX-License-Identifier: Apache-2.0
zephyr_compile_options(-mcpu=${GCC_M_CPU} -mno-sdata -mmpy-option=6)
zephyr_compile_options_ifdef(CONFIG_FLOAT -mfpu=fpuda_all)

zephyr_sources(
  soc.c
  soc_config.c
  )
