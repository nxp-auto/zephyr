# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.13.1)

include($ENV{ZEPHYR_BASE}/cmake/app/boilerplate.cmake NO_POLICY_SCOPE)
project(peripheral_ht)

FILE(GLOB app_sources src/*.c)
target_sources(app PRIVATE
  ${app_sources}
  ../gatt/hts.c
  ../gatt/bas.c
  )

zephyr_library_include_directories($ENV{ZEPHYR_BASE}/samples/bluetooth)
