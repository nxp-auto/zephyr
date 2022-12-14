/*
 * Copyright (c) 2013-2014 Wind River Systems, Inc.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Common linker sections
 *
 * This script defines the memory location of the various sections that make up
 * a Zephyr Kernel image. This file is used by the linker.
 *
 * This script places the various sections of the image according to what
 * features are enabled by the kernel's configuration options.
 *
 * For a build that does not use the execute in place (XIP) feature, the script
 * generates an image suitable for loading into and executing from RAMABLE_REGION by
 * placing all the sections adjacent to each other.  There is also no separate
 * load address for the DATA section which means it doesn't have to be copied
 * into RAMABLE_REGION.
 *
 * For builds using XIP, there is a different load memory address (LMA) and
 * virtual memory address (VMA) for the DATA section.  In this case the DATA
 * section is copied into RAMABLE_REGION at runtime.
 *
 * When building an XIP image the data section is placed into ROMABLE_REGION.  In this
 * case, the LMA is set to __data_rom_start so the data section is concatenated
 * at the end of the RODATA section.  At runtime, the DATA section is copied
 * into the RAMABLE_REGION region so it can be accessed with read and write permission.
 *
 * Most symbols defined in the sections below are subject to be referenced in
 * the Zephyr Kernel image. If a symbol is used but not defined the linker will
 * emit an undefined symbol error.
 *
 * Please do not change the order of the section as the kernel expects this
 * order when programming the MMU.
 */

#define _LINKER

#define _ASMLANGUAGE
#include <linker/linker-defs.h>
#include <offsets.h>
#include <sys/util.h>

#include <linker/linker-tool.h>

#ifdef CONFIG_XIP
	#define ROMABLE_REGION ROM
	#define RAMABLE_REGION RAM
#else
	#define ROMABLE_REGION RAM
	#define RAMABLE_REGION RAM
#endif

#ifdef CONFIG_X86_MMU
	#define MMU_PAGE_SIZE	KB(4)
	#define MMU_PAGE_ALIGN	. = ALIGN(MMU_PAGE_SIZE);
#else
	#define MMU_PAGE_ALIGN
#endif

ENTRY(CONFIG_KERNEL_ENTRY)

/* SECTIONS definitions */
SECTIONS
	{

#include <linker/rel-sections.ld>

    /DISCARD/ :
	{
	*(.plt)
	}

    /DISCARD/ :
	{
	*(.iplt)
	}


	GROUP_START(ROMABLE_REGION)
#ifdef CONFIG_REALMODE
	/* 16-bit sections */
	. = PHYS_RAM_ADDR;

	SECTION_PROLOGUE(boot,,)
	{
	*(.boot)
	. = ALIGN(16);
	} GROUP_LINK_IN(ROMABLE_REGION)
#endif
	. = ALIGN(8);

	_image_rom_start = PHYS_LOAD_ADDR;
#ifndef CONFIG_REALMODE
	_image_text_start = PHYS_LOAD_ADDR;
#else
	_image_text_start = .;
#endif
	SECTION_PROLOGUE(_TEXT_SECTION_NAME,,)
	{
	. = CONFIG_TEXT_SECTION_OFFSET;
	*(.text_start)
	*(".text_start.*")
	*(.text)
	*(".text.*")
	*(.gnu.linkonce.t.*)
	*(.eh_frame_hdr)
	*(.eh_frame)
	*(.init)
	*(.fini)
	*(.eini)
	KEEP(*(.openocd_dbg))
	KEEP(*(".openocd_dbg.*"))

#include <linker/kobject-text.ld>

	MMU_PAGE_ALIGN
	} GROUP_LINK_IN(ROMABLE_REGION)

	_image_text_end = .;
	_image_text_size = _image_text_end - _image_text_start;
	_image_rodata_start = .;

#include <linker/common-rom.ld>

	SECTION_PROLOGUE(_RODATA_SECTION_NAME,,)
	{
	*(.rodata)
	*(".rodata.*")
	*(.gnu.linkonce.r.*)

#ifndef CONFIG_DYNAMIC_INTERRUPTS
	. = ALIGN(8);
	_idt_base_address = .;
#ifdef LINKER_PASS2
	KEEP(*(staticIdt))
#else
	. += CONFIG_IDT_NUM_VECTORS * 8;
#endif /* LINKER_PASS2 */

	. = ALIGN(4);
	_irq_to_interrupt_vector = .;
#ifdef LINKER_PASS2
	KEEP(*(irq_int_vector_map))
#else
	. += CONFIG_MAX_IRQ_LINES;
#endif
#endif /* CONFIG_DYNAMIC_INTERRUPTS */

/* Located in generated directory. This file is populated by the
 * zephyr_linker_sources() Cmake function.
 */
#include <snippets-rodata.ld>
#ifdef CONFIG_SOC_RODATA_LD
#include <soc-rodata.ld>
#endif

#ifdef CONFIG_CUSTOM_RODATA_LD
/* Located in project source directory */
#include <custom-rodata.ld>
#endif

#include <linker/kobject-rom.ld>
	} GROUP_LINK_IN(ROMABLE_REGION)

	MMU_PAGE_ALIGN
	/* ROM ends here, position counter will now be in RAM areas */
#ifdef CONFIG_XIP
	/* For XIP systems, the kernel object tables are kept at the end
	 * of ROM and are unpredictable in size; the true size of the ROM
	 * region isn't know when the MMU tables are generated.
	 * Just set the rom region to extend to the end of flash.
	 */
	_image_rom_end = _image_rom_start + KB(DT_ROM_SIZE);
#else
	_image_rom_end = .;
#endif
	_image_rom_size = _image_rom_end - _image_rom_start;
	_image_rodata_end = _image_rom_end;
	_image_rodata_size = _image_rodata_end - _image_rodata_start;
	GROUP_END(ROMABLE_REGION)
	/*
	 * Needed for dynamic linking which we do not have, do discard
	 */
	/DISCARD/ : {
		*(.got.plt)
		*(.igot.plt)
		*(.got)
		*(.igot)
	}
	/* RAMABLE_REGION */
	GROUP_START(RAMABLE_REGION)

/* Located in generated directory. This file is populated by the
 * zephyr_linker_sources() Cmake function.
 */
#include <snippets-ram-sections.ld>

#ifdef CONFIG_USERSPACE
	/* APP SHARED MEMORY REGION */
#define SMEM_PARTITION_ALIGN(size) MMU_PAGE_ALIGN
#define APP_SHARED_ALIGN  MMU_PAGE_ALIGN

#include <app_smem.ld>

	_image_ram_start = _app_smem_start;
	_app_smem_size = _app_smem_end - _app_smem_start;
	_app_smem_num_words = _app_smem_size >> 2;
	_app_smem_rom_start = LOADADDR(_APP_SMEM_SECTION_NAME);
	_app_smem_num_words = _app_smem_size >> 2;
#endif /* CONFIG_USERSPACE */

	SECTION_PROLOGUE(_BSS_SECTION_NAME, (NOLOAD),)
	{
	MMU_PAGE_ALIGN
#if !defined(CONFIG_USERSPACE)
	_image_ram_start = .;
#endif
	/*
	 * For performance, BSS section is forced to be both 4 byte aligned and
	 * a multiple of 4 bytes.
	 */
	. = ALIGN(4);
	__kernel_ram_start = .;
	__bss_start = .;

	*(.bss)
	*(".bss.*")
	*(COMMON)
	*(".kernel_bss.*")

	/*
	 * As memory is cleared in words only, it is simpler to ensure the BSS
	 * section ends on a 4 byte boundary. This wastes a maximum of 3 bytes.
	 */
	. = ALIGN(4);
	__bss_end = .;
	} GROUP_DATA_LINK_IN(RAMABLE_REGION, RAMABLE_REGION)

	__bss_num_words	= (__bss_end - __bss_start) >> 2;

	SECTION_PROLOGUE(_NOINIT_SECTION_NAME, (NOLOAD),)
	{
	/*
	 * This section is used for non-initialized objects that
	 * will not be cleared during the boot process.
	 */
	*(.noinit)
	*(".noinit.*")
	*(".kernel_noinit.*")

/* Located in generated directory. This file is populated by the
 * zephyr_linker_sources() Cmake function.
 */
#include <snippets-noinit.ld>
#ifdef CONFIG_SOC_NOINIT_LD
#include <soc-noinit.ld>
#endif

	MMU_PAGE_ALIGN

	} GROUP_DATA_LINK_IN(RAMABLE_REGION, RAMABLE_REGION)

	SECTION_DATA_PROLOGUE(_DATA_SECTION_NAME,,)
	{

	__data_ram_start = .;

	*(.data)
	*(".data.*")
	*(".kernel.*")

#ifdef CONFIG_DYNAMIC_INTERRUPTS
	. = ALIGN(4);
	_irq_to_interrupt_vector = .;
#ifdef LINKER_PASS2
	KEEP(*(irq_int_vector_map))
#else
	. += CONFIG_MAX_IRQ_LINES;
#endif /* LINKER_PASS2 */

	z_interrupt_vectors_allocated = .;
#ifdef LINKER_PASS2
	KEEP(*(irq_vectors_alloc))
#else
	. += (CONFIG_IDT_NUM_VECTORS + 7) / 8;
#endif /* LINKER_PASS2 */
#endif /* CONFIG_DYNAMIC_INTERRUPTS */

/* Located in generated directory. This file is populated by the
 * zephyr_linker_sources() Cmake function.
 */
#include <snippets-rwdata.ld>
#ifdef CONFIG_SOC_RWDATA_LD
#include <soc-rwdata.ld>
#endif

#ifdef CONFIG_CUSTOM_RWDATA_LD
/* Located in project source directory */
#include <custom-rwdata.ld>
#endif

#ifdef CONFIG_X86_KPTI
	MMU_PAGE_ALIGN
	z_shared_kernel_page_start = .;
	/* Special page containing supervisor data that is still mapped in
	 * user mode page tables. IDT, GDT, TSSes, trampoline stack, and
	 * any LDT must go here as they always must live in a page that is
	 * marked 'present'. Still not directly user accessible, but
	 * no sensitive data should be here as Meltdown exploits may read it.
	 */
#endif /* CONFIG_X86_KPTI */

#ifdef CONFIG_DYNAMIC_INTERRUPTS
	. = ALIGN(8);
	_idt_base_address = .;
#ifdef LINKER_PASS2
	KEEP(*(staticIdt))
#else
	. += CONFIG_IDT_NUM_VECTORS * 8;
#endif /* LINKER_PASS2 */
#endif /* CONFIG_DYNAMIC_INTERRUPTS */

#ifdef CONFIG_GDT_DYNAMIC
	KEEP(*(.tss))
	. = ALIGN(8);
	_gdt = .;
#ifdef LINKER_PASS2
	KEEP(*(gdt))
#else /* LINKER_PASS2 */

#ifdef CONFIG_USERSPACE
    #define GDT_NUM_ENTRIES 7
#elif defined(CONFIG_HW_STACK_PROTECTION)
    #define GDT_NUM_ENTRIES 5
#else
    #define GDT_NUM_ENTRIES 3
#endif /* CONFIG_X86_USERSPACE */
	. += GDT_NUM_ENTRIES * 8;
#endif /* LINKER_PASS2 */
#endif /* CONFIG_GDT_DYNAMIC */

#ifdef CONFIG_X86_KPTI
	z_trampoline_stack_start = .;
	MMU_PAGE_ALIGN
	z_trampoline_stack_end = .;
	z_shared_kernel_page_end = .;

	ASSERT(z_trampoline_stack_end - z_trampoline_stack_start >= 40,
		"trampoline stack too small");
	ASSERT(z_shared_kernel_page_end - z_shared_kernel_page_start == 4096,
	       "shared kernel area is not one memory page");
#endif /* CONFIG_X86_KPTI */

	. = ALIGN(4);
	} GROUP_DATA_LINK_IN(RAMABLE_REGION, ROMABLE_REGION)

	__data_rom_start = LOADADDR(_DATA_SECTION_NAME);

#include <linker/common-ram.ld>

#ifdef CONFIG_X86_MMU
	/* Can't really predict the size of this section. Anything after this
	 * should not be affected if addresses change between builds (currently
	 * just the gperf tables which is fine).
	 *
	 * However, __mmu_tables_start *must* remain stable between builds,
	 * we can't have anything shifting the memory map beforehand.
	 */
	SECTION_DATA_PROLOGUE(mmu_tables,,)
	{
	/* Page Tables are located here if MMU is enabled.*/
	MMU_PAGE_ALIGN
	__mmu_tables_start = .;
	z_x86_kernel_pdpt = .;
	KEEP(*(mmu_tables));
#ifdef CONFIG_X86_KPTI
	z_x86_user_pdpt = .;
	KEEP(*(user_mmu_tables));
#endif /* CONFIG_X86_KPTI */
	__mmu_tables_end = .;
	} GROUP_DATA_LINK_IN(RAMABLE_REGION, ROMABLE_REGION)
#endif

#include <linker/kobject.ld>

	MMU_PAGE_ALIGN
	__data_ram_end = .;

	/* All unused memory also owned by the kernel for heaps */
	__kernel_ram_end = PHYS_RAM_ADDR + KB(DT_RAM_SIZE);
	__kernel_ram_size = __kernel_ram_end - __kernel_ram_start;

	_image_ram_end = .;
	_image_ram_all = (PHYS_RAM_ADDR + KB(DT_RAM_SIZE)) - _image_ram_start;

	_end = .; /* end of image */

	GROUP_END(RAMABLE_REGION)

#ifndef LINKER_PASS2
	/* static interrupts */
	SECTION_PROLOGUE(intList,,)
	{
	KEEP(*(.spurIsr))
	KEEP(*(.spurNoErrIsr))
	KEEP(*(.intList))
	KEEP(*(.gnu.linkonce.intList.*))
	} > IDT_LIST

#ifdef CONFIG_X86_MMU
	/* Memory management unit*/
	SECTION_PROLOGUE(mmulist,,)
	{
	/* get size of the mmu lists needed for gen_mmu_x86.py*/
	LONG((__MMU_LIST_END__ - __MMU_LIST_START__) / __MMU_REGION_SIZEOF)
	/* Get the start of mmu tables in data section so that the address
	 * of the page tables can be calculated.
	 */
	LONG(__mmu_tables_start)
	__MMU_LIST_START__ = .;
	KEEP(*(.mmulist))
	__MMU_LIST_END__ = .;
	} > MMU_LIST
#endif /* CONFIG_X86_MMU */

#else
	/DISCARD/ :
	{
	KEEP(*(.spurIsr))
	KEEP(*(.spurNoErrIsr))
	KEEP(*(.intList))
	KEEP(*(.gnu.linkonce.intList.*))
	KEEP(*(.mmulist))
	}
#endif



#ifdef CONFIG_CUSTOM_SECTIONS_LD
/* Located in project source directory */
#include <custom-sections.ld>
#endif
/* Located in generated directory. This file is populated by the
 * zephyr_linker_sources() Cmake function.
 */
#include <snippets-sections.ld>

#include <linker/debug-sections.ld>

	/DISCARD/ : { *(.note.GNU-stack) }

	}

#ifdef CONFIG_XIP
/*
 * Round up number of words for DATA section to ensure that XIP copies the
 * entire data section. XIP copy is done in words only, so there may be up
 * to 3 extra bytes copied in next section (BSS). At run time, the XIP copy
 * is done first followed by clearing the BSS section.
 */
__data_size = (__data_ram_end - __data_ram_start);
__data_num_words = (__data_size + 3) >> 2;
#endif
