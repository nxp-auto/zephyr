# SPDX-License-Identifier: Apache-2.0

add_subdirectory(debug)
add_subdirectory(logging)
add_subdirectory_ifdef(CONFIG_BT                   bluetooth)
add_subdirectory_ifdef(CONFIG_CONSOLE_SUBSYS       console)
add_subdirectory_ifdef(CONFIG_SHELL                shell)
add_subdirectory_ifdef(CONFIG_CPLUSPLUS            cpp)
add_subdirectory_ifdef(CONFIG_DISK_ACCESS          disk)
add_subdirectory(fs)
add_subdirectory_ifdef(CONFIG_MCUMGR               mgmt)
add_subdirectory_ifdef(CONFIG_MCUBOOT_IMG_MANAGER  dfu)
add_subdirectory_ifdef(CONFIG_NET_BUF              net)
add_subdirectory_ifdef(CONFIG_USB                  usb)
add_subdirectory(random)
add_subdirectory(storage)
add_subdirectory_ifdef(CONFIG_SETTINGS             settings)
add_subdirectory(fb)
add_subdirectory(power)
add_subdirectory(stats)
add_subdirectory(testsuite)
add_subdirectory_if_kconfig(jwt)
add_subdirectory_if_kconfig(zio)
